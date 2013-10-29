#!/usr/bin/perl -w

use strict;
use Getopt::Long;

my $infile;
my $outfile1;
my $outfile2;

GetOptions ( 
	    "infile=s" => \$infile,
	    "outfile1=s"    => \$outfile1,
	    "outfile2=s"    => \$outfile2,
	   );


convert_blast_genomic_names($infile) if ($infile =~ /genomic/);
$infile .= ".new" if $infile =~ /genomic/;

open (OUT1, ">$outfile1") || die "Can't open $outfile1 for writing: $!";
open (OUT2, ">$outfile2") || die "Can't open $outfile2 for writing: $!";


open (IN, $infile)  || die "Can't open $infile for reading: $!";
my %seen1 = ();
my %seen2 = ();
while (<IN>)
  {
    chomp;
    next unless $_;
    my @line = split/\t/;
    unless ($line[0] && $line[1])
      {
       print STDERR "Skipping line because it is undefined: $_\n";
       next;
      }
    unless ($line[0]=~/\|\|/ && $line[1]=~/\|\|/)
      {
	print STDERR "Skipping entry because it is not formatted correctly with '||':\nEntry 1: $line[0]\nEntry 2: $line[1]\n";
	next;
      }
    
    my @item1 = split/\|\|/, $line[0];
    my @item2 = split/\|\|/, $line[1];
    #genomic comparisons won't have starts and stops in the name file, replace those with the actual hits
    $item1[1] = $line[6] unless defined $item1[1];
    $item1[2] = $line[7] unless defined $item1[2];
    $item2[1] = $line[8] unless defined $item2[1];
    $item2[2] = $line[9] unless defined $item2[2];

    #genomic comparisons need a different name as the default one won't distinguish between blast hits
    my $name1 = $item1[3] ? $line[0] : join ("_", @item1);
    my $name2 = $item2[3] ? $line[1] : join ("_", @item2);
    unless (defined $item1[0] && defined $item1[1] && defined $item1[2])
      {
	print STDERR "Skipping printing output because of missing values:\n";
	print STDERR join ("\n", $item1[0], $item1[1], $item1[2]),"\n";
	next;
      }
    unless (defined $item2[0] && defined $item2[1] && defined $item2[2])
      {
	print STDERR "Skipping printing output because of missing values:\n";
	print STDERR join ("\n", $item2[0], $item2[1], $item2[2]),"\n";
	next;
      }
    print OUT1 join ("\t", $item1[0], $item1[1], $item1[2], $line[0]),"\n" unless $seen1{$name1};
    print OUT2 join ("\t", $item2[0], $item2[1], $item2[2], $line[1]),"\n" unless $seen2{$name2};
    $seen1{$name1} =1;
    $seen2{$name2} =1;
  }
close IN;
close OUT1;
close OUT2;

sub convert_blast_genomic_names
  {
    my $infile = shift;
    open (OUT, ">$infile.new") || die "Can't open $infile.new for writing: $!";
    open (IN, $infile)  || die "Can't open $infile for reading: $!";
    my $count=1;
    while (<IN>)
      {
	chomp;
	next unless $_;
	my @line = split/\t/;
	my @item1 = split/\|\|/, $line[0];
	my @item2 = split/\|\|/, $line[1];
	#add start and stop positions to items if not present (e.g. genomci sequence hits)  
	my ($ori1, $ori2);
	$ori1 = $item1[4];
	$ori2 = $item2[4];
	unless (defined $item1[1] && defined $item1[2] && defined $item1[4])
	  {
	    $item1[1] = $line[6] unless defined $item1[1];
	    $item1[2] = $line[7] unless defined $item1[2];
	    ($item1[1], $item1[2]) = ($item1[2], $item1[1]) if $item1[1]>$item1[2];
	    #determine orientation of the hit relative to the gene (if present)
	    $ori1 = $line[6] > $line[7] ? -1 : 1;
	  }
#	$ori1 = $item1[4] unless $ori1;
	unless (defined $item2[1] && defined $item2[2] && defined $item2[4])
	  {
	    $item2[1] = $line[8] unless defined $item2[1];
	    $item2[2] = $line[9] unless defined $item2[2];
	    ($item2[1], $item2[2]) = ($item2[2], $item2[1]) if $item2[1]>$item2[2];
	    $ori2 = $line[8] > $line[9] ? -1 : 1;
#	    print STDERR $ori2,"!\n";
	  }
	my $ori = $ori1 eq $ori2 ? 1 : -1;
	#for genomic sequences -- needto add genomic_hit and remove 'gi|' or 'lcl|' from begining of fasta header name
	unless ($item1[3])
	  {
	    $item1[3] = "genomic_hit";
	    $item1[0] =~ s/^gi\|//;
	    $item1[0] =~ s/^lcl\|//;
	  }
	unless ($item2[3])
	  {
	    $item2[3] = "genomic_hit";
	    $item2[0] =~ s/^gi\|//;
	    $item2[0] =~ s/^lcl\|//;
	  }
	
#	$item2[3] = "genomic_hit" unless $item2[3];
	unless ($item1[4])
	  {
	    $ori1 = $ori eq 1 ? $ori2 : $ori2*-1;
	  }
	unless ($item2[4])
	  {
	    $ori2 = $ori eq 1 ? $ori1 : $ori1*-1;
	  }
	$item1[4] = $ori1 unless $item1[4];
	$item2[4] = $ori2 unless $item2[4];
	my $name1 = $item1[5] ? $line[0] : join ("||", @item1);
	my $name2 = $item2[5] ? $line[1] : join ("||", @item2);
#	print $name1,"\n";
#	print $name2,"\n";
	$line[0] = $name1;
	$line[1] = $name2;
	print OUT join "\t", @line,"\n";
		$count++;
      }
#    `/bin/mv $infile $infile.orig`;
#    `/bin/mv $infile.tmp $infile`;
  }
