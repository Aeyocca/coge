#! /usr/bin/perl -w
use v5.10;
use strict;

use CGI;
use Digest::MD5 qw(md5_base64);

#use URI::Escape;
use Data::Dumper;
use File::Path;
use HTML::Template;
use JSON::XS;

# CoGe packages
use CoGeX;
use CoGe::Accessory::Jex;
use CoGe::Accessory::LogUser;
use CoGe::Accessory::Web;

no warnings 'redefine';

our (
    $P,        $DBNAME,  $DBHOST,     $DBPORT,   $DBUSER,
    $DBPASS,   $connstr, $PAGE_TITLE, $USER,     $DATE,
    $BASEFILE, $coge,    $cogeweb,    %FUNCTION, $COOKIE_NAME,
    $FORM,     $URL,     $COGEDIR,    $TEMPDIR,  $TEMPURL,
    $YERBA
);

$P = CoGe::Accessory::Web::get_defaults( $ENV{HOME} . 'coge.conf' );
$YERBA = CoGe::Accessory::Jex->new( host => "localhost", port => 5151 );

$DATE = sprintf(
    "%04d-%02d-%02d %02d:%02d:%02d",
    sub { ( $_[5] + 1900, $_[4] + 1, $_[3] ), $_[2], $_[1], $_[0] }
      ->(localtime)
);

$PAGE_TITLE = 'Jobs';

$FORM = new CGI;

$DBNAME = $P->{DBNAME};
$DBHOST = $P->{DBHOST};
$DBPORT = $P->{DBPORT};
$DBUSER = $P->{DBUSER};
$DBPASS = $P->{DBPASS};
$connstr =
  "dbi:mysql:dbname=" . $DBNAME . ";host=" . $DBHOST . ";port=" . $DBPORT;
$coge = CoGeX->connect( $connstr, $DBUSER, $DBPASS );

$COOKIE_NAME = $P->{COOKIE_NAME};
$URL         = $P->{URL};
$COGEDIR     = $P->{COGEDIR};
$TEMPDIR     = $P->{TEMPDIR} . "$PAGE_TITLE/";
mkpath( $TEMPDIR, 0, 0777 ) unless -d $TEMPDIR;
$TEMPURL = $P->{TEMPURL} . "$PAGE_TITLE/";

my ($cas_ticket) = $FORM->param('ticket');
$USER = undef;
($USER) = CoGe::Accessory::Web->login_cas(
    cookie_name => $COOKIE_NAME,
    ticket      => $cas_ticket,
    coge        => $coge,
    this_url    => $FORM->url()
) if ($cas_ticket);
($USER) = CoGe::Accessory::LogUser->get_user(
    cookie_name => $COOKIE_NAME,
    coge        => $coge
) unless $USER;

my $link = "http://" . $ENV{SERVER_NAME} . $ENV{REQUEST_URI};
$link = CoGe::Accessory::Web::get_tiny_link(
    db      => $coge,
    user_id => $USER->id,
    page    => "$PAGE_TITLE.pl",
    url     => $link
);

%FUNCTION = (
    gen_html     => \&gen_html,
    cancel_job   => \&cancel_job,
    schedule_job => \&schedule_job,
);

dispatch();

sub dispatch {
    my %args  = $FORM->Vars;
    my $fname = $args{'fname'};
    if ($fname) {
        die if not defined $FUNCTION{$fname};

        #print STDERR Dumper \%args;
        if ( $args{args} ) {
            my @args_list = split( /,/, $args{args} );
            print $FORM->header, $FUNCTION{$fname}->(@args_list);
        }
        else {
            print $FORM->header, $FUNCTION{$fname}->(%args);
        }
    }
    else {
        print $FORM->header, gen_html();
    }
}

sub get_jobs_for_user {

    #my %opts = @_;
    my @jobs;

    if ( $USER->is_admin ) {
        @jobs =
          $coge->resultset('Job')
          ->search( undef, { order_by => 'job_id DESC' } );
    }
    elsif ( $USER->is_public ) {
        @jobs =
          $coge->resultset('Job')
          ->search( { user_id => 0 }, { order_by => 'job_id ASC', } );
    }
    else {
        @jobs = $USER->jobs->search( undef, { order_by => 'job_id DESC' } );
    }

    my @job_items;

    foreach my $job (@jobs) {
        push @job_items, {
            ID     => $job->job_id,
            LINK   => $job->link,
            PAGE   => $job->page,
            STATUS => get_status_message($job),

            #TODO: Should return the job duration
            RUNTIME => $job->start_time,
            TYPE    => $job->type,
            PID     => $job->process_id,
            LOG     => $job->log_id
        };
    }

    my $template =
      HTML::Template->new( filename => $P->{TMPLDIR} . "$PAGE_TITLE.tmpl" );
    $template->param( LIST_STUFF => 1 );
    $template->param( JOB_LOOP   => \@job_items );

    return $template->output;
}

sub gen_html {
    my $html;
    my $template =
      HTML::Template->new( filename => $P->{TMPLDIR} . 'generic_page.tmpl' );
    $template->param( HELP => "/wiki/index.php?title=$PAGE_TITLE" );
    my $name = $USER->user_name;
    $name = $USER->first_name if $USER->first_name;
    $name .= " " . $USER->last_name if $USER->first_name && $USER->last_name;
    $template->param( USER       => $name );
    $template->param( TITLE      => qq{} );
    $template->param( PAGE_TITLE => $PAGE_TITLE );
    $template->param( LOGO_PNG   => "$PAGE_TITLE-logo.png" );
    $template->param( LOGON      => 1 ) unless $USER->user_name eq "public";
    $template->param( DATE       => $DATE );
    $template->param( BODY       => gen_body() );

    #	$name .= $name =~ /s$/ ? "'" : "'s";
    #	$template->param( BOX_NAME   => $name . " Data Lists:" );
    $template->param( ADJUST_BOX => 1 );
    $html .= $template->output;
}

sub gen_body {
    my $template =
      HTML::Template->new( filename => $P->{TMPLDIR} . "$PAGE_TITLE.tmpl" );
    $template->param( PAGE_NAME  => "$PAGE_TITLE.pl" );
    $template->param( MAIN       => 1 );
    $template->param( LIST_INFO  => get_jobs_for_user() );
    $template->param( ADMIN_AREA => 1 ) if $USER->is_admin;
    return $template->output;
}

sub cancel_job {
    my $job_id = _check_job_args(@_);
    my $job    = _get_validated_job($job_id);

    return return encode_json( {} ) unless defined($job);

    my $status = $YERBA->get_status( $job->id );
    say STDERR $status;

    if ( lc($status) eq 'running' ) {
        $job->update( { status => 3 } );
        return encode_json( $YERBA->terminate( $job->id ) );
    }
    else {
        return encode_json( {} );
    }

}

sub schedule_job {
    my $job_id = _check_job_args(@_);
    my $job    = _get_validated_job($job_id);

    return "fail" unless defined($job);
    return "true";
}

sub get_status_message {
    my $job = shift;

    given ( $job->status ) {
        when (1) { return 'Running'; }
        when (2) { return 'Complete'; }
        when (3) { return 'Cancelled'; }
        when (4) { return 'Terminated'; }
        default  { return 'Running'; }
    }
}

sub cmp_by_start_time {
    my $job1 = shift;
    my $job2 = shift;

    $job1->start_time cmp $job2->start_time;
}

# private functions

sub _get_validated_job {
    my $job_id = shift;
    my $job    = $coge->resultset('Job')->find($job_id);

    if ( ( not defined($job) || $job->user_id == $USER->id )
        && not $USER->is_admin )
    {
        say STDERR "Job.pl: job $job->id expected user id "
          . "$job->user_id but received $USER->id";
        return;
    }

    return $job;
}

sub _check_job_args {
    my %args   = @_;
    my $job_id = $args{job};

    if ( not defined($job_id) ) {
        say STDERR "Job.pl: a job id was not given to cancel_job.";
    }

    return $job_id;
}
