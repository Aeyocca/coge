package CoGeX;

use strict;
use warnings;

use vars qw( $VERSION );

$VERSION = 0.01;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_classes;

=head1 NAME

CoGeX - CoGeX

=head1 SYNOPSIS

  use CoGeX;
  blah blah blah


=head1 DESCRIPTION

Primary object for interacting with CoGe database system.

=head1 USAGE

  use CoGeX;

  my $connstr = 'dbi:mysql:genomes:biocon:3306';
  my $s = CoGeX->connect($connstr, 'cnssys', 'CnS' ); # Biocon's ro user

  my $rs = $s->resultset('Feature')->search(
                {
                  'organism.name' => "Arabidopsis thaliana"
                },
                { join => [ 'dataset', 'organism' ] }
  );

=head1 BUGS


=head1 SUPPORT


=head1 AUTHOR

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

perl(1).

=cut







################################################ subroutine header begin ##

=head2 get_features_in_region

 Usage     : $object->get_features_in_region(start   => $start, 
                                             stop    => $stop, 
                                             chr     => $chr,
                                             dataset_id => $dataset->id());

 Purpose   : gets all the features in a specified genomic region
 Returns   : an array or an array_ref of feature objects (wantarray)
 Argument  : start   => genomic start position
             stop    => genomic stop position
             chr     => chromosome
             dataset_id => dataset id in database (obtained from a
                        CoGe::Dataset object)
                        of the dna seq will be returned
             OPTIONAL
             count   => flag to return only the number of features in a region
 Throws    : none
 Comments  : 

See Also   : 

=cut

################################################## subroutine header end ##

sub get_features_in_region
  {
    my $self = shift;
    my %opts = @_;
    my $start = $opts{'start'} || $opts{'START'} || $opts{begin} || $opts{BEGIN};
    $start = 0 unless $start;
    my $stop = $opts{'stop'} || $opts{STOP} || $opts{end} || $opts{END};
    $stop = $start unless defined $stop;
    my $chr = $opts{chr} || $opts{CHR} || $opts{chromosome} || $opts{CHROMOSOME};
    my $dataset_id = $opts{dataset} || $opts{dataset_id} || $opts{info_id} || $opts{INFO_ID} || $opts{data_info_id} || $opts{DATA_INFO_ID} ;
    my $count_flag = $opts{count} || $opts{COUNT};
    if ($count_flag)
      {
	return $self->resultset('Feature')->count(
						  {
						   "me.chromosome" => $chr,
						   "me.dataset_id" => $dataset_id,
						   -and=>[
							  -or=>[
								-and=>[
								       "me.stop"=>  {"<=" => $stop},
								       "me.stop"=> {">=" => $start},
								      ],
								-and=>[
								       "me.start"=>  {"<=" => $stop},
								       "me.start"=> {">=" => $start},
								      ],
								-and=>[
								       "me.start"=>  {"<=" => $start},
								       "me.stop"=> {">=" => $stop},
								      ],
							       ],
							 ],
						  },
						  {
#						   prefetch=>["locations", "feature_type"],
						  }
						 );
      }
    my @feats = $self->resultset('Feature')->search({
                 "me.chromosome" => $chr,
                 "me.dataset_id" => $dataset_id,
		 -and=>[
			-or=>[
			      -and=>[
				     "me.stop"=>  {"<=" => $stop},
				     "me.stop"=> {">=" => $start},
				    ],
			      -and=>[
				     "me.start"=>  {"<=" => $stop},
				     "me.start"=> {">=" => $start},
				    ],
			      -and=>[
				     "me.start"=>  {"<=" => $start},
				     "me.stop"=> {">=" => $stop},
				    ],
			     ],
		       ],
						    },
						    {
						     prefetch=>["locations", "feature_type"],
						     order_by=>"me.start",
						    }
						   );
    return wantarray ? @feats : \@feats;
  }

sub get_features_in_region_split
  {
    my $self = shift;
    my %opts = @_;
    my $start = $opts{'start'} || $opts{'START'} || $opts{begin} || $opts{BEGIN};
    $start = 0 unless $start;
    my $stop = $opts{'stop'} || $opts{STOP} || $opts{end} || $opts{END};
    $stop = $start unless defined $stop;
    my $chr = $opts{chr} || $opts{CHR} || $opts{chromosome} || $opts{CHROMOSOME};
    my $dataset_id = $opts{dataset} || $opts{dataset_id} || $opts{info_id} || $opts{INFO_ID} || $opts{data_info_id} || $opts{DATA_INFO_ID} ;

    my @startfeats = $self->resultset('Feature')->search({
                 "me.chromosome" => $chr,
                 "me.dataset_id" => $dataset_id,
                 -and => [
                   "me.stop"=> {">=" => $start},
                   "me.stop"=>  {"<=" => $stop},
                 ],
						     },
                 {
                   prefetch=>["locations", "feature_type"],
                 }
						   );
    my @stopfeats = $self->resultset('Feature')->search({
                 "me.chromosome" => $chr,
                 "me.dataset_id" => $dataset_id,
                 -and => [
                   "me.start"=>  {">=" => $start},
                   "me.start"=> {"<=" => $stop},
                 ],
						     },
                 {
                   prefetch=>["locations", "feature_type"],
                 }
						   );

    my %seen;
    my @feats;

    foreach my $f ( @startfeats ) {
      if ( not exists $seen{ $f->id() } ) {
        $seen{$f->id()}+=1;
        push( @feats, $f );
      }
    }

    foreach my $f ( @stopfeats ) {
      if ( not exists $seen{ $f->id() } ) {
        $seen{$f->id()}+=1;
        push( @feats, $f );
      }
    }

    return wantarray ? @feats : \@feats;
  }

################################################ subroutine header begin ##

=head2 count_features_in_region

 Usage     : $object->count_features_in_region(start   => $start, 
                                             stop    => $stop, 
                                             chr     => $chr,
                                             dataset_id => $dataset->id());

 Purpose   : counts the features in a specified genomic region
 Returns   : an integer
 Argument  : start   => genomic start position
             stop    => genomic stop position
             chr     => chromosome
             dataset_id => dataset id in database (obtained from a
                        CoGe::Dataset object)
                        of the dna seq will be returned
 Throws    : none
 Comments  : 

See Also   : 

=cut

################################################## subroutine header end ##

sub count_features_in_region
  {
    my $self = shift;
    my %opts = @_;
    return $self->get_features_in_region (%opts, count=>1);
  }

sub get_current_datasets_for_org
  {
    my $self = shift;
    my %opts = @_ if @_ >1;
    my $orgid = $opts{org} || $opts{orgid} || $opts{organism};
    $orgid = shift unless $orgid;
    return unless $orgid;
    my $rs = $self->resultset('Dataset')->search(
						 {
						  'organism_id'=> $orgid,
						 },
						 {
						  distinct=>'version',
						  order_by=>'version desc',
						 }
						);
    my $version;
    my %data;
    ds_loop: while (my $ds = $rs->next())
      {
	$version = $ds->version unless $version;
	next unless $version == $ds->version;
	my @chrs = $ds->get_chromosomes;
	foreach my $chr (@chrs)
	  {
	    #this is a hack but the general problem is that some organisms have different chromosomes at different versions, however, partially complete genomes will have many contigs and different versions will have different contigs.  So, to get around this, there is a check to see if the chromosome name has contig in it, if so, then only the most current version is used.  Otherwise, all versions are game.
	    next unless $chr;
	    if ($chr =~ /contig/i)
	      {
		next ds_loop if $ds->version ne $version;
	      }
	    $data{$chr} = $ds unless $data{$chr};
	    $data{$chr} = $ds if $ds->version > $data{$chr}->version;
	  }
      }
    %data = map {$_->id,$_} values %data;
    return wantarray ? values %data : [values %data];
  }

sub log_user
  {
    my $self = shift;
    my %opts = @_;
    my $user = $opts{user};
    my $uid = ref($user) =~ /User/ ? $user->id : $user;
    unless ($uid =~ /^\d+$/)
      {
	warn "Error adding user_id to User_session.  Not a valid uid: $uid\n";
	return;
      }
    #FIRST REMOVE ALL ENTRIES FOR THIS USER
    foreach my $item ($self->resultset('UserSession')->search(user_id=>$uid))
      {
	next unless $item;
	$item->delete;
      }
    #ADD NEW ENTRY
    my $item = $self->resultset('UserSession')->create({user_id=>$uid, date=>\'NOW()'});
    return $item->id;
  }


1;
