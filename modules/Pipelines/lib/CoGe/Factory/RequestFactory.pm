package CoGe::Factory::RequestFactory;

use Moose;
use CoGe::Request::Empty;
use CoGe::Request::Experiment;
use CoGe::Request::ExperimentAnalysis;
use CoGe::Request::Genome;
use CoGe::Request::SynMap;
use CoGe::Request::TwoGenomes;
use Data::Dumper;

has 'user'    => (
    is        => 'ro',
    required  => 1
);

has 'db'      => (
    is        => 'ro',
    required  => 1
);

has 'jex'     => (
    is        => 'ro',
    required  => 1
);

sub get {
    my ($self, $message) = @_;
    unless (defined $message && defined $message->{type}) {
        print STDERR "RequestFactory: error: invalid message\n";
        return;
    }

    my $options = {
        db         => $self->db,
        jex        => $self->jex,
        user       => $self->user,
        parameters => $message->{parameters}
    };

    my $type = $message->{type};
    if ($type eq "export_gff" ||
        $type eq "export_fasta" ||
        $type eq "export_genome" ||
        $type eq "load_experiment" ||
        $type eq "load_batch" ||
        $type eq "load_annotation")
    {
        return CoGe::Request::Genome->new($options);
    }
    elsif ($type eq "export_experiment") {
        return CoGe::Request::Experiment->new($options);
    }
    elsif ($type eq "analyze_snps" ||
           $type eq "analyze_expression" ||
           $type eq "analyze_metaplot" || 
           $type eq "analyze_diversity") 
    {
        return CoGe::Request::ExperimentAnalysis->new($options);
    }
    elsif ($type eq "load_genome" ||
           $type eq "coge_blast") {
        return CoGe::Request::Empty->new($options);
    }
    elsif ($type eq "dotplot_dots")
    {
        return CoGe::Request::TwoGenomes->new($options);
    }
    elsif ($type eq "synmap" ||
        $type eq "synmap3d")
    {
        return CoGe::Request::SynMap->new($options);
    }
    else {
        print STDERR "RequestFactory: error: unrecognized job type '", $type, "'\n";
        return;
    }
}

1;
