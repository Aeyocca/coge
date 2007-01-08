package CoGe::Genome::DB::Data_source;
use strict;
use base 'CoGe::Genome::DB';

BEGIN {
    use Exporter ();
    use vars qw ($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    $VERSION     = 0.1;
    @ISA         = (@ISA, qw (Exporter));
     #Give a hoot don't pollute, do not export more than needed by default
    @EXPORT      = qw ();
    @EXPORT_OK   = qw ();
    %EXPORT_TAGS = ();
    __PACKAGE__->table('data_source');
    __PACKAGE__->columns(All=>qw{data_source_id name description link});
    __PACKAGE__->has_many(dataset=>'CoGe::Genome::DB::Dataset');
}


########################################### main pod documentation begin ##
# Below is the stub of documentation for your module. You better edit it!


=head1 NAME

Genome::DB::Data_source - Genome::DB::Data_source

=head1 SYNOPSIS

  use Genome::DB::Data_source
  blah blah blah


=head1 DESCRIPTION

Stub documentation for this module was created by ExtUtils::ModuleMaker.
It looks like the author of the extension was negligent enough
to leave the stub unedited.

Blah blah blah.


=head1 USAGE



=head1 BUGS



=head1 SUPPORT



=head1 AUTHOR

	Eric Lyons
	CPAN ID: AUTHOR
	XYZ Corp.
	elyons@nature.berkeley.edu
	http://a.galaxy.far.far.away/modules

=head1 COPYRIGHT

This program is free software licensed under the...

	The Artistic License

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

perl(1).

=cut

############################################# main pod documentation end ##





sub data_info
  {
    my $self = shift;
    print STDERR "data_info is obselete. Please use dataset";
    return $self->dataset();
  }

sub desc
  {
    my $self = shift;
    return $self->descriptions(@_);
  }

sub id
  {
    my $self = shift;
    return $self->data_source_id();
  }

################################################ subroutine header begin ##

=head2 resolve_data_source

 Usage     : my $ds = resolve_data_source($data_source_thing);
 Purpose   : given a data source name, a data source database id, or a data source object,
             this will return the data source object for you
 Returns   : CoGe::Genome::DB::Data_source object
 Argument  : data_source_thing can be a data source name, database id, 
             or object
 Throws    : will throw a warning if a valid object was not created
 Comments  : 

See Also   : 

=cut

################################################## subroutine header end ##

sub resolve_data_source
  {
    my $self = shift;
    my $dsin = shift;
    my $dsout;
    if (ref ($dsin) =~ /Data_source/i) #we were passed an object
      {
	$dsout = $dsin;
      }
    elsif ($dsin =~ /^\d+$/) #only numbers, probably a database id
      {
	$dsout = $self->retrieve($dsin);
      }
    else #probably a name. . .
      {
	($dsout) = $self->search_like (name=>"%".$dsin."%")
      }
    warn "unable to resolve data $dsin in Data_source->resolve_data_source" unless ref ($dsout) =~ /Data_source/i;
    return $dsout;
  }

################################################ subroutine header begin ##

=head2 resolve

 Usage     : alias for $self->resolve_data_source
 Purpose   : alias for $self->resolve_data_source
See Also   : resolve_data_source

=cut

################################################## subroutine header end ##

sub resolve
  {
    my $self = shift;
    return $self->resolve_data_source(@_);
  }


1; #this line is important and will help the module return a true value

################################################ subroutine header begin ##

=head2 sample_function

 Usage     : How to use this function/method
 Purpose   : What it does
 Returns   : What it returns
 Argument  : What it wants to know
 Throws    : Exceptions and other anomolies
 Comments  : This is a sample subroutine header.
           : It is polite to include more pod and fewer comments.

See Also   : 

=cut

################################################## subroutine header end ##
