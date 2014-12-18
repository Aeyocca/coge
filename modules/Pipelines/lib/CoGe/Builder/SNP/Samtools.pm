package CoGe::Builder::SNP::Samtools;

use v5.14;
use warnings;
use strict;

use Carp;
use Data::Dumper;
use File::Spec::Functions qw(catdir catfile);
use File::Basename qw(basename);

use CoGe::Accessory::Jex;
use CoGe::Accessory::Utils qw(to_filename);
use CoGe::Accessory::Web qw(get_defaults);
use CoGe::Core::Storage qw(get_genome_file get_workflow_paths);
use CoGe::Builder::CommonTasks;

our $CONF = CoGe::Accessory::Web::get_defaults();
our $JEX = CoGe::Accessory::Jex->new( host => $CONF->{JOBSERVER}, port => $CONF->{JOBPORT} );

BEGIN {
    use vars qw ($VERSION @ISA @EXPORT @EXPORT_OK);
    require Exporter;

    $VERSION   = 0.1;
    @ISA       = qw(Exporter);
    @EXPORT    = qw(run build);
    #@EXPORT_OK = qw(build);
}

sub run {
    my %opts = @_;

    # Required arguments
    my $user = $opts{user} or croak "A user was not specified";

    my $workflow = $JEX->create_workflow( name => 'Running the SAMtools SNP-finder pipeline', init => 1 );
    my ($staging_dir, $result_dir) = get_workflow_paths( $user->name, $workflow->id );
    $workflow->logfile( catfile($result_dir, 'debug.log') );

    my @jobs = build({
        staging_dir => $staging_dir,
        result_dir => $result_dir,
        user => $user,
        wid  => $workflow->id,
    });

    # Add all the jobs to the workflow
    foreach (@jobs) {
        $workflow->add_job(%{$_});
    }

    # Submit the workflow
    my $result = $JEX->submit_workflow($workflow);
    if ($result->{status} =~ /error/i) {
        return (undef, "Could not submit workflow");
    }

    return ($result->{id}, undef);
}

sub build {
    my $opts = shift;

    # Required arguments
    my $genome = $opts->{genome};
    my $input_file = $opts->{input_file}; # path to bam file
    my $user = $opts->{user};
    my $wid = $opts->{wid};
    my $staging_dir = $opts->{staging_dir};
    my $result_dir = $opts->{result_dir};
    my $metadata = $opts->{metadata};

    my $gid = $genome->id;
    my $FASTA_CACHE_DIR = catdir($CONF->{CACHEDIR}, $gid, "fasta");
    die "ERROR: CACHEDIR not specified in config" unless $FASTA_CACHE_DIR;
    my $fasta_file = get_genome_file($gid);
    my $reheader_fasta =  to_filename($fasta_file) . ".reheader.fasta";

    my $conf = {
        staging_dir => $staging_dir,
        result_dir  => $result_dir,

        bam         => $input_file,
        fasta       => catfile($FASTA_CACHE_DIR, $reheader_fasta),
        bcf         => catfile($staging_dir, qq[snps.raw.bcf]),
        vcf         => catfile($staging_dir, qq[snps.flt.vcf]),

        annotations => generate_experiment_metadata(),
        username    => $user->name,
        metadata    => $metadata,
        wid         => $wid,
        gid         => $gid,
    };

    my @jobs;

    # Build all the job
    push @jobs, create_fasta_reheader_job(
        fasta => $fasta_file,
        reheader_fasta => $reheader_fasta,
        cache_dir => $FASTA_CACHE_DIR
    );

    push @jobs, create_find_snps_job($conf);
    push @jobs, create_filter_snps_job($conf);
    push @jobs, create_load_vcf_job($conf);

    return @jobs;
}

sub create_find_snps_job {
    my $opts = shift;

    # Required arguments
    my $reference = $opts->{fasta};
    my $alignment = $opts->{bam};
    my $snps = $opts->{bcf};

    my $subopts = {
        samtools => {
            command => $CONF->{SAMTOOLS} || "samtools",
            subtask => "mpileup",
            args    => {
                u => [],
                f => [],
            },
            inputs => [
                basename($reference),
                basename($alignment),
            ],
        },
        bcf => {
            command => $CONF->{BCFTOOLS} || "bcftools",
            subtask => "view",
            args    => {
                b => [],
                v => [],
                c => [],
                g => [],
            },
            inputs => [
            ],
        },
    };

    my @subcommands =  (
        _subcommand($subopts->{samtools}),
        _subcommand($subopts->{bcf}),
    );

    # Pipe commands together
    my $command = join " | ", @subcommands;

    # Get the output filename
    my $output = basename($snps);

    return {
        cmd => qq[$command - > $output],
        inputs => [
            $reference,
            $alignment,
        ],
        outputs => [
            $snps,
        ],
        description => "Identifying SNPs using SAMtools method ...",
    };
}

sub create_filter_snps_job {
    my $opts = shift;

    # Required arguments
    my $snps = $opts->{bcf};
    my $filtered_snps = $opts->{vcf};

    # Optional arguments
    my $depth = $opts->{depth} || 100;

    my $subopts = {
        bcf => {
            command => $CONF->{BCFTOOLS} || "bcftools",
            subtask => "view",
            args    => {
            },
            inputs => [
                basename($snps),
            ],
        },

        vcf => {
            command => $CONF->{VCFTOOLS} || "vcfutils.pl",
            subtask => "varFilter",
            args    => {
                D => [$depth],
            },
            inputs => [
            ],
        },
    };

    my @subcommands =  (
        _subcommand($subopts->{bcf}),
        _subcommand($subopts->{vcf}),
    );

    # Pipe commands together
    my $command = join " | ", @subcommands;

    # Get the output filename
    my $output = basename($filtered_snps);

    return {
        cmd => qq[$command > $output],
        inputs  => [
            $snps,
        ],
        outputs => [
            $filtered_snps,
        ],
        description => "Filtering SNPs ...",
    };
}

sub _subcommand {
    my $opts = shift;
    my $cmd = $opts->{command};
    my $subtask = $opts->{subtask};
    my $args = $opts->{args};

    # create parameter string
    my @params = map { @{$args->{$_}} ? qq[-$_ @{$args->{$_}}] : qq[-$_] } keys %{$args};

    my @inputs = @{$opts->{inputs}} if $opts->{inputs};

    return qq[$cmd $subtask @params @inputs];
}

sub generate_experiment_metadata {
    my @annotations = (
        qq{http://genomevolution.org/wiki/index.php/Identifying_SNPs||note|Generated by CoGe's SNP-finder Pipeline (SAMtools method)},
    );
    return join(';', @annotations);
}


1;
