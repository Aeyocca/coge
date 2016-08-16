package CoGe::Builder::Expression::qTeller;

use v5.14;
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use File::Basename qw(fileparse basename dirname);
use File::Spec::Functions qw(catdir catfile);
use JSON qw(decode_json);
use URI::Escape::JavaScript qw(unescape);

use CoGe::Accessory::TDS qw(read);
use CoGe::Accessory::Utils qw(to_filename);
use CoGe::Accessory::Web qw(get_defaults get_command_path);
use CoGe::Accessory::Workflow;
use CoGe::Core::Storage qw(get_genome_file get_workflow_paths get_workflow_results_file);
use CoGe::Core::Metadata qw(to_annotations tags_to_string);
use CoGe::Builder::CommonTasks;

our $CONF = CoGe::Accessory::Web::get_defaults();

BEGIN {
    use vars qw ($VERSION @ISA @EXPORT @EXPORT_OK);
    require Exporter;

    $VERSION = 0.1;
    @ISA     = qw(Exporter);
    @EXPORT  = qw(build);
}

sub build {
    my %opts = @_;
    my $genome = $opts{genome};
    my $user = $opts{user};
    my $input_file = $opts{input_file}; # path to bam file
    my $metadata = $opts{metadata};
    my $additional_metadata = $opts{additional_metadata};
    my $wid = $opts{wid};
    my $params = $opts{params};

    # Setup paths
    my ($staging_dir, $result_dir) = get_workflow_paths($user->name, $wid);
    my $gid = $genome->id;
    my $FASTA_CACHE_DIR = catdir($CONF->{CACHEDIR}, $gid, "fasta");
    die "ERROR: CACHEDIR not specified in config" unless $FASTA_CACHE_DIR;

    # Check if genome has annotations
    my $isAnnotated = $genome->has_gene_features;

    # Set metadata for the pipeline being used
    my $annotations = generate_additional_metadata($params, $isAnnotated);
    my @annotations2 = CoGe::Core::Metadata::to_annotations($additional_metadata);
    push @$annotations, @annotations2;

    # Reheader the fasta file
    my @tasks;
    my $fasta = get_genome_file($gid);
    my $reheader_fasta = to_filename($fasta) . ".reheader.faa";
    push @tasks, create_fasta_reheader_job( 
        fasta => $fasta, 
        reheader_fasta => $reheader_fasta, 
        cache_dir => $FASTA_CACHE_DIR
    );
    
    # Generate cached gff if genome is annotated
    my $gff_file;
    if ($isAnnotated) {
        my $gff = create_gff_generation_job(gid => $gid, organism_name => $genome->organism->name);
        $gff_file = $gff->{outputs}->[0];
        push @tasks, $gff;
    }

    # Generate bed file of read depth
    my $bed = create_bed_file_job(
        bam => $input_file,
        staging_dir => $staging_dir,
        params => $params,
    );
    push @tasks, $bed;

    # Filter bed file
    my $filtered_bed = create_filter_bed_file_job($bed->{outputs}->[0], $staging_dir);
    push @tasks, $filtered_bed;
    
    # Load bed experiment (read depth)
    my $load_bed_task = create_load_bed_job(
        metadata => $metadata, 
        gid => $gid, 
        bed_file => $filtered_bed->{outputs}->[0], 
        user => $user,
        wid => $wid, 
        annotations => $annotations, 
        staging_dir => $staging_dir, 
        result_dir => $result_dir
    );
    push @tasks, $load_bed_task;

    # Check for annotations required by cufflinks
    my $include_csv;
    my $load_csv_task;
    if ($isAnnotated) {
        $include_csv = 1;

        # Run cufflinks
        my $cuff = create_cufflinks_job($gff_file, catfile($FASTA_CACHE_DIR, $reheader_fasta), $input_file, $staging_dir);
        push @tasks, $cuff;

        # Convert final output into csv
        my $parse_cuff = create_parse_cufflinks_job($cuff->{outputs}->[0], $staging_dir);
        push @tasks, $parse_cuff;

        # Load csv experiment (fpkm measurements)
        $load_csv_task = create_load_csv_job(
            metadata => $metadata, 
            gid => $gid, 
            csv_file => $parse_cuff->{outputs}->[0], 
            user => $user, 
            wid => $wid,
            annotations => $annotations,
            staging_dir => $staging_dir, 
            result_dir => $result_dir
        );
        push @tasks, $load_csv_task;
    }

    # Save outputs for retrieval by downstream tasks
    my @done_files = (
        $load_bed_task->{outputs}->[0]
    );
    push @done_files, $load_csv_task->{outputs}->[0] if ($include_csv);
    
    return {
        tasks => \@tasks,
        done_files => \@done_files
    };
}

sub generate_additional_metadata {
    my ($params, $isAnnotated) = @_;
    
    my @annotations;
    push @annotations, qq{https://genomevolution.org/wiki/index.php/Expression_Analysis_Pipeline||note|Generated by CoGe's RNAseq Analysis Pipeline};
    push @annotations, qq{note|samtools depth -q } . $params->{'-q'};
    push @annotations, qq{note|cufflinks (default parameters)} if $isAnnotated;

    return \@annotations;
}

sub create_cufflinks_job { #TODO move into CommonTasks.pm
    my ($gff, $fasta, $bam, $staging_dir) = @_;
    my $cmd = 'nice ' . get_command_path('CUFFLINKS');

    return {
        cmd => $cmd,
        script => undef,
        args => [
            ['-q', '', 0], # suppress output other than warning/error messages
            ['-u', '', 0],
            ['-b', $fasta, 1],
            ['-p', 24, 0],
            ['', $bam, 1]
        ],
        inputs => [
            $gff,
            $bam,
            $fasta
        ],
        outputs => [
            catfile($staging_dir, "genes.fpkm_tracking")
        ],
        description => "Measuring FPKM using cufflinks..."
    };
}

sub create_bed_file_job { #TODO move into CommonTasks.pm
    my %opts = @_;

    # Required arguments
    my $bam = $opts{bam};
    my $staging_dir = $opts{staging_dir};

    # Optional arguments
    my $params = $opts{params} // {}; #/
    my $q = $params->{'-q'} // 20; #/

    my $name = to_filename($bam);
    my $cmd = get_command_path('SAMTOOLS');
    my $PILE_TO_BED = catfile($CONF->{SCRIPTDIR}, "pileup_to_bed.pl");
    die "ERROR: SCRIPTDIR not specified in config" unless $PILE_TO_BED;

    return {
        cmd => $cmd,
        script => undef,
        args => [
            #['mpileup', '', 0], # mdb removed 11/4/15 COGE-676
            #['-D', '', 0],      # mdb removed 11/4/15 COGE-676
            #['-Q', $Q, 0],      # mdb removed 11/4/15 COGE-676
            ['depth', '', 0],    # mdb added 11/4/15 COGE-676
            ['-q', $q, 0],       # mdb added 11/4/15 COGE-676
            ['', $bam, 1],
            ['|', 'perl', 0],
            [$PILE_TO_BED, '', 0],
            ['>', $name . ".bed",  0]
        ],
        inputs => [
            $bam,
        ],
        outputs => [
            catfile($staging_dir, $name . ".bed")
        ],
        description => "Measuring read depth..."
    };
}

sub create_filter_bed_file_job { #TODO move into CommonTasks.pm
    my $bed = shift;
    my $staging_dir = shift;
    my $name = to_filename($bed);
    my $cmd = $CONF->{SAMTOOLS};
    my $NORMALIZE_BED = catfile($CONF->{SCRIPTDIR}, "normalize_bed.pl");
    die "ERROR: SCRIPTDIR not specified in config" unless $NORMALIZE_BED;

    return {
        cmd => "perl",
        script => undef,
        args => [
            [$NORMALIZE_BED, $bed, 0],
            ['>', $name . '.normalized.bed', 0]
        ],
        inputs => [
            $bed,
        ],
        outputs => [
            catfile($staging_dir, $name . ".normalized.bed")
        ],
        description => "Normalizing read depth..."
    };
}

sub create_parse_cufflinks_job { #TODO move into CommonTasks.pm
    my $cufflinks = shift;
    my $staging_dir = shift;

    my $name = to_filename($cufflinks);

    my $cmd = get_command_path('PYTHON');
    my $script = catfile($CONF->{SCRIPTDIR}, 'parse_cufflinks.py');

    return {
        cmd => "$cmd $script",
        script => undef,
        args => [
            ["", $cufflinks, 0],
            ["", $name . ".csv", 0]
        ],
        inputs => [
            $cufflinks
        ],
        outputs => [
            catfile($staging_dir, $name . ".csv")
        ],
        description => "Processing FPKM results ..."
    };
}

sub create_load_csv_job { #TODO move into CommonTasks.pm
    my %opts = @_;
    my $metadata = $opts{metadata};
    my $gid = $opts{gid};
    my $csv_file = $opts{csv_file};
    my $user = $opts{user};
    my $annotations = $opts{annotations};
    my $staging_dir = $opts{staging_dir};
    my $result_dir = $opts{result_dir};
    my $wid = $opts{wid};
    
    my $cmd = catfile($CONF->{SCRIPTDIR}, "load_experiment.pl");
    die "ERROR: SCRIPTDIR not specified in config" unless $cmd;
    
    my $result_file = get_workflow_results_file($user->name, $wid);
    
    my $annotations_str = '';
    $annotations_str = join(';', @$annotations) if (defined $annotations && @$annotations);
    
    my @tags = ( 'Expression' ); # add Expression tag
    push @tags, @{$metadata->{tags}} if $metadata->{tags};
    my $tags_str = tags_to_string(\@tags);

    return {
        cmd => $cmd,
        script => undef,
        args => [
            ['-user_name', $user->name, 0],
            ['-name', '"'.$metadata->{name}.' (FPKM)'.'"', 0],
            ['-desc', qq{"Transcript expression measurements"}, 0],
            ['-version', '"'.$metadata->{version}.'"', 0],
            ['-restricted', $metadata->{restricted}, 0],
            ['-source_name', '"'.$metadata->{source}.'"', 0],
            ['-gid', $gid, 0],
            ['-wid', $wid, 0],
            ['-tags', qq{"$tags_str"}, 0],
            ['-annotations', qq{"$annotations_str"}, 0],
            ['-staging_dir', "./load_csv", 0],
            ['-file_type', "csv", 0],
            ['-data_file', $csv_file, 0],
            ['-config', $CONF->{_CONFIG_PATH}, 1]
        ],
        inputs => [
            $CONF->{_CONFIG_PATH},
            $csv_file
        ],
        outputs => [
            [catdir($staging_dir, "load_csv"), 1],
            catfile($staging_dir, "load_csv/log.done"),
            $result_file
        ],
        description => "Loading FPKM results as new experiment..."
    };
}

sub create_load_bed_job { #TODO move into CommonTasks.pm
    my %opts = @_;
    my $metadata = $opts{metadata};
    my $gid = $opts{gid};
    my $user = $opts{user};
    my $annotations = $opts{annotations};
    my $staging_dir = $opts{staging_dir};
    my $result_dir = $opts{result_dir};
    my $wid = $opts{wid};
    my $bed_file = $opts{bed_file};

    my $cmd = catfile($CONF->{SCRIPTDIR}, "load_experiment.pl");
    die "ERROR: SCRIPTDIR not specified in config" unless $cmd;
    
    my $result_file = get_workflow_results_file($user->name, $wid);
    
    my $annotations_str = '';
    $annotations_str = join(';', @$annotations) if (defined $annotations && @$annotations);
    
    my @tags = ( 'Expression' ); # add Expression tag
    push @tags, @{$metadata->{tags}} if $metadata->{tags};
    my $tags_str = tags_to_string(\@tags);
    
    return {
        cmd => $cmd,
        script => undef,
        args => [
            ['-user_name', $user->name, 0],
            ['-name', '"'.$metadata->{name}." (read depth)".'"', 0],
            ['-desc', qq{"Read depth per position"}, 0],
            ['-version', '"'.$metadata->{version}.'"', 0],
            ['-restricted', $metadata->{restricted}, 0],
            ['-gid', $gid, 0],
            ['-wid', $wid, 0],
            ['-source_name', '"'.$metadata->{source}.'"', 0],
            ['-tags', qq{"$tags_str"}, 0],
            ['-annotations', qq{"$annotations_str"}, 0],
            ['-staging_dir', "./load_bed", 0],
            ['-file_type', "bed", 0],
            ['-data_file', "$bed_file", 0],
            ['-config', $CONF->{_CONFIG_PATH}, 1]
        ],
        inputs => [
            $CONF->{_CONFIG_PATH},
            $bed_file,
        ],
        outputs => [
            [catdir($staging_dir, "load_bed"), 1],
            catfile($staging_dir, "load_bed/log.done"),
            $result_file
        ],
        description => "Loading read depth measurements as new experiment..."
    };
}

1;
