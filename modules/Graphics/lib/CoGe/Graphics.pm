package CoGe::Graphics;
use strict;
use base qw(Class::Accessor);
use CoGe::Graphics::Chromosome;
use CoGe::Graphics::Feature;
use CoGe::Graphics::Feature::Gene;
use CoGe::Graphics::Feature::NucTide;
use CoGe::Graphics::Feature::GAGA;
use CoGe::Graphics::Feature::Sigma54;
use CoGe::Graphics::Feature::Exon_motifs;
use CoGe::Graphics::Feature::AminoAcid;
use CoGe::Graphics::Feature::Domain;
use CoGe::Graphics::Feature::Block;
use CoGe::Genome;
use CoGeX;
use Data::Dumper;
use Benchmark;
use Carp;

use vars qw($VERSION $MAX_FEATURES $MAX_NT $DEBUG $BENCHMARK);
$VERSION     = '0.1';
__PACKAGE__->mk_accessors(
"MAX_FEATURES",
"MAX_NT",
"DEBUG", 
);


#################### subroutine header begin ####################

=head2 sample_function

 Usage     : How to use this function/method
 Purpose   : What it does
 Returns   : What it returns
 Argument  : What it wants to know
 Throws    : Exceptions and other anomolies
 Comment   : This is a sample subroutine header.
           : It is polite to include more pod and fewer comments.

See Also   : 

=cut

#################### subroutine header end ####################


sub new
{
    my ($class, %parameters) = @_;

    my $self = bless ({}, ref ($class) || $class);

    return $self;
}


#################### main pod documentation begin ###################
## Below is the stub of documentation for your module. 
## You better edit it!


=head1 NAME

CoGe::Graphics - CoGe::Graphics

=head1 SYNOPSIS

  use CoGe::Graphics;
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
	elyons@nature.berkeley.edu

=head1 COPYRIGHT

This program is free software licensed under the...

	The Artistic License

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

perl(1).

=cut

#################### main pod documentation end ###################


#################### subroutine header begin ####################

=head2 genomic_view

 Usage     : CoGe::Graphics->genomic_view(
				   start=>$start,
				   stop=>$stop,
				   di=>$di,
				   version=>$version,
				   org=>$org_id,
				   chr=>$chr,
				   iw=>$iw,
				   ih=>$ih,
				   mag=>$mag,
				   z=>$z,
				   file=>$file,
				   start_pict=>$start_pict,
				   simple=>$simple,
				   csh=>$chr_start_height,
				   cmh=>$chr_mag_height,
				   fsh=>$feat_start_height,
				   fmh=>$feat_mag_height,
				   fids=>\@fids,
				   fns=>\@fnames,
				   forcefit=>$forcefit,
                                   layers=>\@layers,
				   );
 Purpose   : mama of a function.  Docs to come.
 Returns   : 
 Argument  : 
 Throws    : 
 Comment   : 
           : 

See Also   : 

=cut

#################### subroutine header end ####################



sub genomic_view
  {
    my $self = shift;
    $self = new("CoGe::Graphics") unless ref($self) =~ /Graphics/;;
    my %opts = @_;
    my $start = $opts{'start'} || $opts{'x'} ||0;#28520458;
    my $stop = $opts{'stop'};# || 6948000;#6949600;#190000;
    $start = 1 unless defined $start;
    #$stop = $start unless $stop;
    my $ds = $opts{'ds'} || $opts{'di'};
    my $version = $opts{'v'} || $opts{'version'};
    my $org = $opts{'o'} || $opts{'org'} ||$opts{'organism'} || $opts{'org_id'} || $opts{'oid'};
    my $chr = $opts{'chr'} ||$opts{'chromosome'};
    my $iw = $opts{'iw'} || $opts{'width'} || $opts{'tile size'}|| $opts{'tile_size'} || 256;
    my $ih = $opts{'ih'};
    my $mag = $opts{'m'} || $opts{'mag'} || $opts{'magnification'};
    my $z = $opts{'z'};
    my $file = $opts{'file'};# || "./tmp/pict.png";
    my $start_pict = $opts{'start_pict'};
    my $simple = $opts{'simple'};
    my $chr_start_height = $opts{'csh'} || 200;
    my $chr_mag_height = $opts{'cmh'} || 5;
    my $feat_start_height = $opts{'fsh'} || 10;
    my $feat_mag_height = $opts{'fmh'} || 2;
    $BENCHMARK = $opts{'bm'} || 0;
    my $fids = $opts{'fid'} || $opts{'fids'}; #used to highlight special features by their database id
    my $fnames = $opts{'fn'} || $opts{'fns'}|| $opts{'fnames'}; #used to highlight special features by their name
    my $forcefit = $opts{'forcefit'} || 0;
    my $img_map_name = $opts{'img_map'};
    my $layers = process_layers($opts{layers});
    my $major_tick_labels = $opts{major_tick_labels} || 1;
    my $minor_tick_labels = $opts{minor_tick_labels} || -1;
#    print STDERR Dumper $opts{layers}, $layers;

    $DEBUG = $opts{debug} || $opts{DEBUG} || 0;
    $self->DEBUG($DEBUG);
    print STDERR "Options: ".Dumper \%opts if $self->DEBUG;

    $fids = [$fids] unless ref ($fids) =~ /array/i;
    $fnames = [$fnames] unless ref ($fnames) =~ /array/i;
    ##some limits to keep from blowing our stack
    $self->MAX_FEATURES($iw*10); #10 features per pixel
    $self->MAX_NT($iw*100000); #100,000 nts per pixel
    my $t0 = new Benchmark if $BENCHMARK;

    #CoGe objects that we will need
    my $connstr = 'dbi:mysql:dbname=genomes;host=biocon;port=3306';
    my $coge = CoGeX->connect($connstr, 'cnssys', 'CnS' );
    #$coge->storage->debugobj(new DBIxProfiler());
    $coge->storage->debug(1);
    my $db = new CoGe::Genome;
    my $c = new CoGe::Graphics::Chromosome;

    $org = $db->get_organism_obj->resolve_organism($org) if $org;
    $ds = $db->get_dataset_obj->resolve_dataset($ds) if $ds;

    if ($ds) #there can be additional information about a chromosome for a particular version of the organism that is not in the same data_information.  Let's go find the organism_id and version for the specified data information item.
      {
	$org = $ds->org unless $org;
	$version = $ds->version unless $version;
	($chr) = $ds->get_chromosomes() unless $chr;
      }

    if ($org && !$ds)
      {
	$version = $db->get_dataset_obj->get_current_version_for_organism(org=>$org) unless $version;
	($ds) = $db->get_dataset_obj->search({version=>$version, organism_id=>$org->id});
	($chr) = $ds->get_chromosomes() unless $chr;
      }


    unless (defined $start && $ds && $chr)
      {
	my $dsid = $ds ? $ds->id : "none";
	carp "missing needed parameters: Start: $start, Info_id: ".$dsid.", Chr: $chr\n";
	return 0;
      }
    print STDERR "generating image for ds: ".$ds->name ." (".$ds->id.")\n" if $self->DEBUG;
    
    my %dids; #we will store a list of data_information objects that are related to the current dataset
    my $ta = new Benchmark if $BENCHMARK;
    if ($org)
      {	
	foreach my $did ( $db->get_dataset_obj->search({organism_id=>$org->id, version=>$version}))
	  {
	    $dids{$did} = 1;
	  }
      }
    my $tb = new Benchmark if $BENCHMARK;
    my $finddid_time = timestr(timediff($tb, $ta))  if $BENCHMARK;
    
    $dids{$ds}=1 if $ds;

    my @dids = keys %dids;
    my $tc = new Benchmark if $BENCHMARK;
    foreach my $did (@dids)
      {
	my ($tstart, $tstop) = $self->initialize_c(ds=>$did,
						   chr=>$chr,
						   iw=>$iw,
						   ih=>$ih,
						   z=>$z,
						   mag=>$mag,
						   start=>$start,
						   stop=>$stop,
						   db=>$db,
						   c=>$c,
						   start_pict=>$start_pict,
						   csh=>$chr_start_height,
						   cmh=>$chr_mag_height,
						   fsh=>$feat_start_height,
						   fmh=>$feat_mag_height,
						   forcefit=>$forcefit,
						   feature_labels=>1,
						   major_tick_labels=>$major_tick_labels,
						   minor_tick_labels=>$minor_tick_labels,
						   mag_off=>1,
						  ) unless $c->chr_length;
	if ($c->chr_length)
	  {
	    $start = $tstart;
	    $stop = $tstop;
	    print STDERR "processing nucleotides\n" if $self->DEBUG;
	    $self->process_nucleotides(start=>$start, stop=>$stop, chr=>$chr, ds=>$did, db=>$db, c=>$c, layers=>$layers);
	    last;
	  }
      }
    my $td = new Benchmark if $BENCHMARK;
    my $init_c_time = timestr(timediff($td, $tc)) if $BENCHMARK;

    unless ($c->chr_length)
      {
	warn "error initializing the chromosome object.  Failed for valid chr_length\n";
	return(0);
      }
    my $t1 = new Benchmark if $BENCHMARK;
    foreach my $did (keys %dids)
      {
	my $taa = new Benchmark if $BENCHMARK;
	print STDERR "processing features\n" if $self->DEBUG;
	$self->process_features(start=>$start, stop=>$stop, chr=>$chr, ds=>$did, db=>$db, c=>$c, fids=>$fids, fnames=>$fnames, layers=>$layers) unless $simple;
	my $tab = new Benchmark if $BENCHMARK;
	my $feat_time = timestr(timediff($tab, $taa)) if $BENCHMARK;
	print STDERR " processing did $did:   $feat_time\n" if $BENCHMARK;
      }
    unless ($layers->{ruler} || $layers->{chromosome} || $layers->{all})
      {
	$c->draw_ruler(0);
	$c->draw_chromosome(0);
      }
    

    my $t2 = new Benchmark if $BENCHMARK;
    print STDERR "generating image: $file\n" if $self->DEBUG;
    $self->generate_output(file=>$file, c=>$c);	
    print STDERR "generating image map : $img_map_name\n" if $self->DEBUG && $img_map_name;
    my $img_map = $c->generate_imagemap(name=>$img_map_name) if $img_map_name;
    my $t3 = new Benchmark if $BENCHMARK;
    my $init_time = timestr(timediff($t1, $t0)) if $BENCHMARK;
    my $feature_time = timestr(timediff($t2, $t1)) if $BENCHMARK;
    my $draw_time = timestr(timediff($t3, $t2)) if $BENCHMARK;
    print STDERR "Image height: ", $c->ih,"\n";

    print STDERR qq{
BENCHMARKING GenomePNG.pl

  Finding DID:          $finddid_time
  Init chr obj:         $init_c_time
Total Initialization:   $init_time
Processing features:    $feature_time
Image generation:       $draw_time


} if $BENCHMARK;

    return $img_map if $img_map;
  }

sub initialize_c
  {
    my $self = shift;
#    unless ref($self) =~ /Graphics/ unshift @_, $self;
    my %opts = @_;
    my $ds = $opts{ds};
    my $chr = $opts{chr};
    my $iw = $opts{iw};
    my $ih = $opts{ih};
    my $z = $opts{z};
    my $mag = $opts{mag};
    my $mag_off = $opts{mag_off};
    my $start = $opts{start};
    my $stop = $opts{stop};
    my $chr_length = $opts{chr_length};
    my $db = $opts{db};
    my $c = $opts{c};
    my $csh=$opts{csh} || $opts{chr_start_height};
    my $cmh=$opts{cmh} || $opts{chr_mag_height};
    my $fsh=$opts{fsh} || $opts{feature_start_height};
    my $fmh=$opts{fmh} || $opts {feature_mag_height};
    my $draw_chr = $opts{draw_chr};
    my $draw_ruler = $opts{draw_ruler};
    my $draw_chr_end = $opts{draw_chr_end};
    my $forcefit = $opts{forcefit};
    my $start_pict = $opts{'start_pict'} || 'left';
    my $feature_labels = $opts{feature_labels};
    my $fill_labels = $opts{fill_labels};
    my $debug = $opts{debug} || 0;
    my $invert_chromosome = $opts{invert_chromosome};
    my $major_tick_labels = $opts{major_tick_labels};
    my $minor_tick_labels = $opts{minor_tick_labels};
    my $overlap_adjustment = $opts{overlap_adjustment};
    my $draw_hi_qual = $opts{draw_hi_qual};
    $debug = 1 if $c->DEBUG;
    $draw_ruler = 1 unless defined $opts{draw_ruler};
    $chr_length = $db->get_genomic_sequence_obj->get_last_position(ds=>$ds, chr=>$chr) if $ds && !$chr_length;
    return unless $chr_length;
    $c->chr_length($chr_length);
    $c->mag_scale_type("constant_power");
    $c->iw($iw);
    $c->ih($ih) if $ih;
    $c->max_mag((10));
    $c->DEBUG($debug);
    $c->feature_labels($feature_labels) if defined $feature_labels;
    $c->fill_labels($fill_labels) if defined $fill_labels ;
    $c->draw_chromosome($draw_chr) if defined $draw_chr;
    $c->draw_ruler($draw_ruler) if defined $draw_ruler;
    $c->draw_chr_end($draw_chr_end) if defined $draw_chr_end;
    $c->chr_start_height($csh) if defined $csh;
    $c->chr_mag_height($cmh) if defined $cmh;;
    $c->feature_start_height($fsh) if defined $fsh;
    $c->feature_mag_height($fmh) if defined $fmh;
    $c->major_tick_labels($major_tick_labels) if defined $major_tick_labels;
    $c->minor_tick_labels($minor_tick_labels) if defined $minor_tick_labels;
    $c->overlap_adjustment($overlap_adjustment) if defined $overlap_adjustment;
    $c->mag_off($mag_off) if defined $mag_off;
    $c->invert_chromosome($invert_chromosome) if defined $invert_chromosome;
    $c->draw_hi_qual($draw_hi_qual) if defined $draw_hi_qual;
    if (defined $z) #the $z val is used by the program for making tiles of genomic views.
                #by convention, a z value of 0 means maximum magnification which is
        	#opposite the convention used in chromosome.pm.  Thus, we need
        	#to reformat the z value appropriately
      {
         my ($max) = sort {$b <=> $a} keys %{$c->mag_scale};
         $mag = $max-$z;
         $mag = 1 if $mag < 1;
         $mag = $max if $mag > $max;
         $c->start_picture($start_pict);
      }
    if (defined $mag)
      {
        $c->mag($mag);
      }
    else
      {
        $c->mag($c->mag-1);
      }
    $c->set_region(start=>$start, stop=>$stop, forcefit=>$forcefit);
    $start = $c->_region_start;
    $stop= $c->_region_stop;
    #let's add the max top and bottom tracks to the image to keep its size constant
    $c->_max_track(3);
#    my $f1= CoGe::Graphics::Feature->new({start=>1, order => 3, strand => 1});
#    $f1->merge_percent(0);
#    $c->add_feature($f1);
#    my $f2= CoGe::Graphics::Feature->new({start=>1, order => 3, strand => -1});
#    $f2->merge_percent(0);
#    $c->add_feature($f2);
    return ($start, $stop);
}

sub process_nucleotides
  {
    my $self = shift;
    my %opts = @_;
    my $start = $opts{start};
    my $stop = $opts{stop};
    my $seq = $opts{seq};
    $start = 1 unless $start;
    $stop = length $seq if $seq && !$stop;
    if ($self->MAX_NT && abs ($stop-$start) > $self->MAX_NT())
      {
	warn "exceeded nucleotide limit of ",$self->MAX_NT()," (requested: ".abs($stop-$start).")\n";
	return;
      }
    my $chr = $opts{chr};
    my $ds = $opts{ds};
    my $db = $opts{db};
    my $c = $opts{c};
#    $seq = uc($db->get_genomic_sequence_obj->get_sequence(start=>$start, stop=>$stop, chr=>$chr, ds=>$ds)) unless $seq;
    my $layers = $opts{layers};
#    print STDERR Dumper $layers;
#    print STDERR "IN $0: start: $start, stop: $stop\n";
    #process nucleotides
    my $t7 = new Benchmark if $BENCHMARK;
    $seq = uc($db->get_genomic_sequence_obj->get_sequence(start=>$start, end=>$stop, chr=>$chr, dataset=>$ds)) unless $seq; 
    my $t8 = new Benchmark if $BENCHMARK;
    my $seq_len = length $seq;
    my $chrs = int (($c->_region_stop-$c->_region_start)/$c->iw);
    $chrs = 1 if $chrs < 1;
    my $pos = 0;
    $start = 1 if $start < 1;
    if ($layers->{gc} || $layers->{nt} || $layers->{all})
      {
	while ($pos < $seq_len)
	  {
	    my $subseq = substr ($seq, $pos, $chrs);
	    my $rcseq = substr ($seq, $pos, $chrs);
	    $rcseq =~ tr/ATCG/TAGC/;
	    next unless $subseq && $rcseq;
	    my $options = $layers->{gc} ? "gc" : "nt";
	    my $f1 = CoGe::Graphics::Feature::NucTide->new({nt=>$subseq, strand=>1, start =>$pos+$start, options=>$options}) if $layers->{gc} || $layers->{nt} || $layers->{all};
	    my $f2 = CoGe::Graphics::Feature::NucTide->new({nt=>$rcseq, strand=>-1, start =>$pos+$start, options=>$options}) if $layers->{gc} || $layers->{nt} || $layers->{all};
	    if ($layers->{nt} || $layers->{all})
	      {
		$f1->show_label(1); 
		$f2->show_label(1);
		$f1->use_external_image(1);
		$f2->use_external_image(1);
	      }
	    #my $f2 = CoGe::Graphics::Feature::Exon_motifs->new({nt=>$rcseq, strand=>-1, start =>$pos+$start});
	    #my $f2 = CoGe::Graphics::Feature::GAGA->new({nt=>$rcseq, strand=>-1, start =>$pos+$start});
	    #	my $f2 = CoGe::Graphics::Feature::Sigma54->new({nt=>$rcseq, strand=>-1, start =>$pos+$start});
#	    $f1->transparency(50) if $f1;
#	    $f2->transparency(50) if $f2;
	    $c->add_feature($f1) if $f1;
	    $c->add_feature($f2) if $f2;
	    $pos+=$chrs;
	  }
      }
    my $t9 = new Benchmark if $BENCHMARK;
    my $time1 = timestr(timediff($t8, $t7)) if $BENCHMARK;
    my $time2 = timestr(timediff($t9, $t8)) if $BENCHMARK;
    print STDERR qq{
 Time to get nt seq              :  $time1
 Time to process nt for graphics :  $time2
} if $BENCHMARK;

    return $chrs;
  }

sub process_features
  {
    my $self = shift;
    #process features
    my %opts = @_;
    my $start = $opts{start};
    my $stop = $opts{stop};
    my $chr = $opts{chr};
    my $ds = $opts{ds};
    my $db = $opts{db};
    my $c = $opts{c};
    my $accn = $opts{accn};
    my $print_names = $opts{print_names};
    my $fids = $opts{fids};
    my $fnames = $opts{fnames};
    my $layers = $opts{layers};
    return unless $layers->{all} || $layers->{features};
    my $sstart = $start - ($stop - $start);
    my $sstop = $stop + ($stop - $start);
    $sstart = 0 if $sstart < 0;
    my $chr_length = $db->get_genomic_sequence_obj->get_last_position(ds=>$ds);
    $sstop = $chr_length unless defined $sstop;
    $sstop = $chr_length if $sstop > $chr_length;
    my $feat_count = $db->get_feature_obj->count_features_in_region(start=>$sstart, end=>$sstop, dataset=>$ds, chr=>$chr);
#    print "$sstart - $sstop: feats: $feat_count\n";
    my @cds_feats;
    if ($feat_count > $self->MAX_FEATURES)
      {
	warn "exceeded maximum number of features ",$self->MAX_FEATURES(),". ($feat_count requested)\nskipping.\n";
	return;
      }
    my $size = $stop - $start;
    $size = 0 unless $c->overlap_adjustment;
    $size = 0 if $feat_count > 100;
    $size *=2 if $feat_count < 20;
    $size = $start if $start-$size < 0;
#    print "Getting features: $start - $stop : adjust: $size\n";
    foreach my $feat ($db->get_feature_obj->get_features_in_region(start=>$start-$size, end=>$stop+$size, dataset=>$ds, chr=>$chr))
      {
        my $f;
	print STDERR "Feat info: Name: ",$feat->type->name,", Type: ",$feat->type->name, ", Loc: ", $feat->start,"-",$feat->stop,"\n" if $self->DEBUG;
        if (($layers->{features}{gene} || $layers->{all}) && $feat->type->name =~ /Gene/i)
          {
	    $f = CoGe::Graphics::Feature::Gene->new();
	    $f->color([255,0,0,50]);
	    foreach my $loc ($feat->locs)
	      {
		$f->add_segment(start=>$loc->start, stop=>$loc->stop);
		$f->strand($loc->strand);
	      }
	    $f->order(1);
	    $f->overlay(1);
	    $f->mag(0.5);
          }
        elsif (($layers->{features}{cds} || $layers->{all}) && $feat->type->name =~ /CDS/i)
          {
        	$f = CoGe::Graphics::Feature::Gene->new();
        	$f->color([0,255,0, 50]);
        	$f->order(1);
		$f->overlay(3);
		push @cds_feats, $feat;
		if ($accn)
		  {
		    foreach my $name (@{$feat->{QUALIFIERS}{names}})
		      {
			$f->color([255,255,0]) if $name =~ /$accn/i;
		      }
		  }
          }
        elsif (($layers->{features}{mrna} || $layers->{all}) && $feat->type->name =~ /mrna/i || $feat->type->name =~ /exon/i)
          {
        	$f = CoGe::Graphics::Feature::Gene->new();
        	$f->color([0,0,255, 50]);
        	$f->order(1);
		$f->overlay(2);
		$f->mag(0.75);
          }
        elsif (($layers->{features}{rna} || $layers->{all}) && $feat->type->name =~ /[^m]rna/i)
          {
        	$f = CoGe::Graphics::Feature::Gene->new();
        	$f->color([200,200,200, 50]);
        	$f->order(1);
		$f->overlay(2);
		if ($accn)
		  {
		    foreach my $name (@{$feat->{QUALIFIERS}{names}})
		      {
			$f->color([255,255,0]) if $name =~ /$accn/i;
		      }
		  }

          }
        elsif (($layers->{features}{domain} || $layers->{all}) && $feat->type->name =~ /functional domains/i)
          {
	    $f = CoGe::Graphics::Feature::Domain->new();
	    $f->order(2);
	    $f->overlay(1);
          }
	elsif (($layers->{features}{cns} || $layers->{all}) && $feat->type->name =~ /CNS/i)
          {
	    $f = CoGe::Graphics::Feature::Block->new();
	    $f->order(1);
	    my $color = [ 255, 100, 255];
	    $f->color($color);
          }
	elsif ($feat->type->name =~ /source/i)
	  {
	    next;
	  }
	elsif ($layers->{features}{other} || $layers->{all})
	  {
	    $f = CoGe::Graphics::Feature::Block->new();
	    $f->order(3);
	    my $color = [ 255, 100, 0];
	    $f->color($color);
	  }
	if (($layers->{features}{protein} || $layers->{all}) && $feat->type->name =~ /CDS/i)
	  {

	    $self->process_proteins(genomic_feat=>$feat, c=>$c);
			
	  }

        next unless $f;
	foreach my $id (@$fids)
	  {
	    next unless $id;
	    $f->color([255,255,0]) if $feat->id eq $id;
	  } 
	foreach my $name (@$fnames)
	  {
	    next unless $name;
	    foreach my $n (map {$_->name} $feat->names)
	      {
		if ($n =~ /^$name$/i)
		  {
		    $f->color([255,255,0]);
		    $f->label($name);
		  }
	      }
	  }
        foreach my $loc ($feat->locs)
	  {
	    print STDERR "\tadding feature location: ",$loc->start,"-", $loc->stop,". . ." if $self->DEBUG;
	    $f->add_segment(start=>$loc->start, stop=>$loc->stop);
	    $f->strand($loc->strand);
	    print "done!\n" if $self->DEBUG;
	  }
	my ($name) = sort { length ($b) <=> length ($a) || $a cmp $b} map {$_->name} $feat->names;
	$f->description($feat->annotation_pretty_print);
	$f->link("GeLo.pl?".join("&", "chr=".$feat->chr,"ds=".$feat->dataset->id,"z=10", "INITIAL_CENTER=".$feat->start.",0"));
	$f->label($name) if $print_names;
        $f->type($feat->type->name);
#	print STDERR Dumper $f;
        $c->add_feature($f);
	print STDERR "\tfinished process feature.\n" if $self->DEBUG;
    }
    return \@cds_feats;
  }

sub generate_output
  {
    my $self = shift;
    my %opts = @_;
    my $file = $opts{file};
    my $c = $opts{c};
    if ($file)
      {
        $c->generate_png(file=>$file);
      }
    else
      {
        print "Content-type: image/png\n\n";
        $c->generate_png();
      }
  } 

sub process_proteins
  {
    my $self = shift;
    return $self->draw_prots(@_);
  }

sub draw_prots
  {
    my $self = shift;
    my %opts = @_;
    my $feat = $opts{genomic_feat};
    my $c = $opts{c};
    #Do we have any protein sequence we can use?
    my $chrs;
    foreach my $seq ($feat->sequences)
      {
	next unless $seq->seq_type->name =~ /prot/i;
	my ($pseq) = $seq->sequence_data;
	my $lastaa = 0;
	$chrs = int ((($c->_region_length)/$c->iw)/3+.5); 
	$chrs = 1 if $chrs < 1;
	my $pos = 0;
	while ($pos < length $pseq)
	  {
	    my $aseq = substr($pseq, $pos, $chrs);
	    #print STDERR "length: ", (length $pseq), ", pos: ", $pos, ", chrs: ", $chrs, ", aseq: ", $aseq,"\n";
	    if($pos+$chrs == (length $pseq))
		{$lastaa = 1;}
	    foreach my $loc ($seq->get_genomic_locations(start=>$pos+1, stop=>$pos+$chrs))
	      {
		
#		next if $loc->stop < $c->_region_begin;
#		next if $loc->start > $c->_region_end;
		print STDERR "Adding protein feature: $aseq at position ", $loc->start,"-", $loc->stop,"\n" if $self->DEBUG;
		my $ao = CoGe::Graphics::Feature::AminoAcid->new({aa=>$aseq, start=>$loc->start, stop=>$loc->stop, strand => $loc->strand, order=>2, lastaa=>$lastaa});
		$ao->skip_overlap_search(1);
		$ao->mag(0.75);
		$ao->overlay(2);
		$c->add_feature($ao);
		delete $loc->{__Changed}; #silence the warning from Class::DBI when location is destroyed
	      }
	    
	    $pos+=$chrs;
	  }
      }
    return $chrs;
  }

sub process_layers
  {
    my $layers = shift;
    my %valid_layers = 
      (
       ruler=>"ruler",
       chromosome=>"chromosome",
       chr=>"chromosome",
       cds=>"cds",
       coding=>"cds",
       exons=>"cds",
       exon=>"cds",
       rna=>"rna",
       mrna=>"mrna",
       gene=>"gene",
       proteins=>"protein",
       protein=>"protein",
       pro=>"protein",
       funcitonal_domains=>"domain",
       domains=>"domain",
       domain=>"domain",
       other=>"other",
       cns=>"cns",
       nt=>"nt",
       nucleotides=>"nt",
       nucleotide=>"nt",
       nuc=>"nt",
       gc=>"gc",
       background=>"background",
       all=>"all",
      );
    my %features = 
      (
       cds=>1,
       mrna=>1,
       protein=>1,
       gene=>1,
       domain=>1,
       other=>1,
       cns=>1,
       rna=>1,
      );
    my %layers;
    foreach my $layer (@$layers)
      {
#	my $strand;
	$layer = lc($layer);

	next unless $valid_layers{$layer};
#	$layer = "rna" if $layer =~ /rna/;
	if ($features{$valid_layers{$layer}})
	  {
	    $layers{features}{$valid_layers{$layer}}=1;
	  }
	else
	  {
	    $layers{$valid_layers{$layer}}=1;
	  }
      }
    $layers{all}=1 unless keys %layers;
    return \%layers;
  }

1;
# The preceding line will help the module return a true value

