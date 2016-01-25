package CoGe::Builder::Methylation::BWAmeth;

use v5.14;
use strict;
use warnings;

use Clone qw(clone);
use Data::Dumper qw(Dumper);
use File::Spec::Functions qw(catdir catfile);
use CoGe::Accessory::Utils qw(to_filename to_filename_without_extension);
use CoGe::Accessory::Web qw(get_defaults);
use CoGe::Accessory::Workflow;
use CoGe::Core::Storage qw(get_genome_file get_workflow_paths);
use CoGe::Core::Metadata qw(to_annotations);
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
    my $opts = shift;
    my $genome = $opts->{genome};
    my $user = $opts->{user};
    my $input_file = $opts->{input_file}; # path to bam file
    my $metadata = $opts->{metadata};
    my $additional_metadata = $opts->{additional_metadata};
    my $wid = $opts->{wid};
    my $read_params = $opts->{read_params};
    my $methylation_params = $opts->{methylation_params};

    # Setup paths
    my ($staging_dir, $result_dir) = get_workflow_paths($user->name, $wid);

    # Set metadata for the pipeline being used
    my $annotations = generate_additional_metadata();
    my @annotations2 = CoGe::Core::Metadata::to_annotations($additional_metadata);
    push @$annotations, @annotations2;

    #
    # Build the workflow
    #
    my (@tasks, @done_files);
    
    if ($methylation_params->{'picard-deduplicate'}) {
        my $deduplicate_task = create_picard_deduplicate_job(
            bam_file => $input_file,
            read_type => $read_params->{read_type},
            staging_dir => $staging_dir
        );
        push @tasks, $deduplicate_task;
        $input_file = $deduplicate_task->{outputs}[0];
    }

    push @tasks, create_pileometh_plot_job(
        bam_file => $input_file,
        gid => $genome->id,
        staging_dir => $staging_dir
    );
    
    my $extract_methylation_task = create_pileometh_extraction_job(
        bam_file => $input_file,
        gid => $genome->id,
        staging_dir => $staging_dir,
        params => $methylation_params
    );
    push @tasks, $extract_methylation_task;
    
    my @outputs = @{$extract_methylation_task->{outputs}};
    foreach my $file (@outputs) {
        my ($name) = $file =~ /(CHG|CHH|CpG)/;
        
        my $import_task = create_pileometh_import_job(
            input_file => $file,
            params => $methylation_params,
            staging_dir => $staging_dir,
            name => $name
        );
        push @tasks, $import_task;
        
        my $md = clone($metadata);
        $md->{name} .= " ($name methylation)";
        
        push @tasks, create_load_experiment_job(
            user => $user,
            metadata => $md,
            staging_dir => $staging_dir,
            wid => $wid,
            gid => $genome->id,
            input_file => $import_task->{outputs}[0],
            name => $name,
            annotations => $annotations
        );
    }

    return {
        tasks => \@tasks,
        done_files => \@done_files
    };
}

sub generate_additional_metadata {
    my @annotations;
    push @annotations, qq{https://genomevolution.org/wiki/index.php/Expression_Analysis_Pipeline||note|Generated by CoGe's RNAseq Analysis Pipeline};

    return \@annotations;
}

sub create_picard_deduplicate_job {
    my %opts = @_;
    my $bam_file = $opts{bam_file};
    my $staging_dir = $opts{staging_dir};
    
    die "ERROR: PICARD is not in the config." unless $CONF->{PICARD};
    my $cmd = 'java -jar ' . $CONF->{PICARD};
    
    my $output_file = $bam_file . '.dedup';
    
    return {
        cmd => $cmd,
        script => undef,
        args => [
            ['MarkDuplicates', '', 0],
            ['REMOVE_DUPLICATES=true', '', 0],
            ["INPUT=$bam_file", '', 0],
            ["METRICS_FILE=$bam_file.metrics", '', 0],
            ["OUTPUT=$output_file", '', 0],
        ],
        inputs => [
            $bam_file,
        ],
        outputs => [
            $output_file,
        ],
        description => "Deduplicating PCR artifacts using Picard..."
    };
}

sub create_pileometh_plot_job {
    my %opts = @_;
    my $bam_file = $opts{bam_file};
    my $gid = $opts{gid};
    my $staging_dir = $opts{staging_dir};
    
    my $cmd = $CONF->{PILEOMETH} || 'PileOMeth';
    my $BWAMETH_CACHE_FILE = catfile($CONF->{CACHEDIR}, $gid, 'bwameth_index', 'genome.faa.reheader.faa');
    
    my $output_prefix = 'pileometh';
    
    return {
        cmd => $cmd,
        script => undef,
        args => [
            ['mbias', '', 0],
            ['--CHG', '', 0],
            ['--CHH', '', 0],
            ['', $BWAMETH_CACHE_FILE, 0],
            ['', $bam_file, 0],
            [$output_prefix, '', 0]
        ],
        inputs => [
            $bam_file
        ],
        outputs => [
            catfile($staging_dir, $output_prefix . '_OB.svg'),
            catfile($staging_dir, $output_prefix . '_OT.svg')
        ],
        description => "Plotting methylation bias with PileOMeth..."
    };
}

sub create_pileometh_extraction_job {
    my %opts = @_;
    my $bam_file = $opts{bam_file};
    my $gid = $opts{gid};
    my $staging_dir = $opts{staging_dir};
    my $params = $opts{params};
    my $q  = $params->{'pileometh-min_converage'} // 10;
    my $ot = $params->{'--OT'} // '0,0,0,0';
    my $ob = $params->{'--OB'} // '0,0,0,0';
    
    my $cmd = $CONF->{PILEOMETH} || 'PileOMeth';
    my $BWAMETH_CACHE_FILE = catfile($CONF->{CACHEDIR}, $gid, 'bwameth_index', 'genome.faa.reheader.faa');
    
    my $output_prefix = to_filename_without_extension($bam_file);
    
    return {
        cmd => $cmd,
        script => undef,
        args => [
            ['extract', '', 0],
            ['--CHG', '', 0],
            ['--CHH', '', 0],
            ['-q', $q, 0],
            ['--OT', $ot, 0],
            ['--OB', $ob, 0],
            ['', $BWAMETH_CACHE_FILE, 0],
            ['', $bam_file, 1]
        ],
        inputs => [
            $bam_file
        ],
        outputs => [
            catfile($staging_dir, $output_prefix . '_CpG.bedGraph'),
            catfile($staging_dir, $output_prefix . '_CHH.bedGraph'),
            catfile($staging_dir, $output_prefix . '_CHG.bedGraph')
        ],
        description => "Extracting methylation calls with PileOMeth..."
    };
}

sub create_pileometh_import_job {
    my %opts = @_;
    my $input_file = $opts{input_file};
    my $staging_dir = $opts{staging_dir};
    my $name = $opts{name};
    my $params = $opts{params};
    my $c = $params->{'pileometh-min_converage'} // 10;
    
    my $cmd = catfile($CONF->{SCRIPTDIR}, 'methylation', 'coge-import_pileometh.py');
    my $output_file = $input_file . '.filtered.coge.csv';
    
    return {
        cmd => $cmd,
        script => undef,
        args => [
            ['-u', 'f', 0],
            ['-c', $c, 0],
            ['', $input_file, 1]
        ],
        inputs => [
            $input_file
        ],
        outputs => [
            $output_file
        ],
        description => "Converting $name..."
    };
}

1;
