#! /usr/bin/perl -w
use strict;

use CGI;
use CGI::Carp 'fatalsToBrowser';
use Data::Dumper;
use CoGeX;
use DBIxProfiler;
use CoGe::Accessory::LogUser;
use CoGe::Accessory::Web;
#use CoGeX;

use vars qw($P $DATE $DEBUG $TEMPDIR $TEMPURL $USER $FORM $FID $coge);
$P = CoGe::Accessory::Web::get_defaults();
$ENV{PATH} = $P->{COGEDIR};
$TEMPDIR = $P->{TEMPDIR};
$TEMPURL = $P->{TEMPURL};

# set this to 1 to print verbose messages to logs
$DEBUG = 0;
$| = 1; # turn off buffering
($USER) = CoGe::Accessory::LogUser->get_user();
$FORM = new CGI;
$FID = $FORM->param('fid');

$coge = CoGeX->dbconnect();
#$coge->storage->debugobj(new DBIxProfiler());
#$coge->storage->debug(1);

#print "Content-Type: text/html\n\n";
my $rhtml = gen_html(featid=>$FID, ) if $FID;
$rhtml = "No annotations" unless $rhtml;
print "Content-Type: text/html\n\n";
print $rhtml;

sub gen_html
  {
    my %args = @_;
    my $featid = $args{featid};
    return unless $featid;
    my $feat = $coge->resultset('Feature')->find($featid);
    my @names = $feat->names;
    my $html = join ("\t", @names)."\n";
    return $html;
  }
