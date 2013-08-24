#! /usr/bin/perl -w

use strict;
use CGI;
use JSON::XS;
use HTML::Template;
use Data::Dumper;
use File::Path;
use CoGe::Accessory::Web;
use CoGeX;

no warnings 'redefine';

use vars qw($P $PAGE_NAME $PAGE_TITLE $USER $coge %FUNCTION $FORM);

$PAGE_TITLE = 'Sources';
$PAGE_NAME  = "$PAGE_TITLE.pl";

$FORM = new CGI;

( $coge, $USER, $P ) = CoGe::Accessory::Web->init(
    ticket     => $FORM->param('ticket') || undef,
    url        => $FORM->url,
    page_title => $PAGE_TITLE
);

%FUNCTION = (
    create_source      => \&create_source,
    delete_source      => \&delete_source,
    get_sources        => \&get_sources,
    edit_source_info   => \&edit_source_info,
    update_source_info => \&update_source_info
);

CoGe::Accessory::Web->dispatch( $FORM, \%FUNCTION, \&gen_html );

sub create_source {
    my %opts = @_;
    return 0 unless $USER->is_admin;
    return "No specified name!" unless $opts{name};

    # Check if one already exists with same name
    my $source =
      $coge->resultset('DataSource')->find( { name => $opts{name} } );
    return "A data source with the same name already exists" if ($source);

    my $link = $opts{link};
    $link =~ s/^\s+//;
    $link = 'http://' . $link if ( not $link =~ /^(\w+)\:\/\// );

    # Create the new data source
    $coge->resultset('DataSource')->create(
        {
            name        => $opts{name},
            description => $opts{desc},
            link        => $link
        }
    );

    return 1;
}

sub delete_source {
    my %opts = @_;
    return 0 unless $USER->is_admin;
    my $dsid = $opts{dsid};
    return "Must have valid data source id\n" unless ($dsid);

    # Delete the data source
    my $ds = $coge->resultset('DataSource')->find($dsid);
    $ds->delete;

    return 1;
}

sub get_sources {

    #my %opts = @_;

    my @sources;
    foreach my $source ( sort { $a->name cmp $b->name }
        $coge->resultset('DataSource')->all() )
    {
        push @sources,
          {
            NAME => $source->name . ' (id' . $source->id . ')',
            DESC => ( $source->description ? $source->description : undef ),
            LINK => (
                $source->link
                ? '<a href="'
                  . $source->link
                  . '" target=_blank>'
                  . $source->link . '</a>'
                : undef
            ),
            BUTTONS => $USER->is_admin,
            EDIT_BUTTON =>
"<span class='link ui-icon ui-icon-gear' onclick=\"edit_source_info({dsid: '"
              . $source->id
              . "'});\"></span>",
            DELETE_BUTTON =>
"<span class='link ui-icon ui-icon-trash' onclick=\"delete_source({dsid: '"
              . $source->id
              . "'});\"></span>"
          };
    }

    my $template =
      HTML::Template->new( filename => $P->{TMPLDIR} . 'Sources.tmpl' );
    $template->param( SOURCE_TABLE => 1 );
    $template->param( SOURCE_LOOP  => \@sources );
    $template->param( BUTTONS      => $USER->is_admin );

    return $template->output;
}

sub edit_source_info {
    my %opts = @_;
    return 0 unless $USER->is_admin;
    my $dsid = $opts{dsid};
    return 0 unless $dsid;

    my $ds = $coge->resultset('DataSource')->find($dsid);
    my $desc = ( $ds->description ? $ds->description : '' );

    my $template =
      HTML::Template->new( filename => $P->{TMPLDIR} . 'Sources.tmpl' );
    $template->param( EDIT_SOURCE_INFO => 1 );
    $template->param( DSID             => $dsid );
    $template->param( NAME             => $ds->name );
    $template->param( DESC             => $desc );
    $template->param( LINK             => $ds->link );

    my %data;
    $data{title}  = 'Edit Source Info';
    $data{name}   = $ds->name;
    $data{desc}   = $desc;
    $data{link}   = $ds->link;
    $data{output} = $template->output;

    return encode_json( \%data );
}

sub update_source_info {
    my %opts = @_;
    return 0 unless $USER->is_admin;
    my $dsid = $opts{dsid};
    return 0 unless $dsid;
    my $name = $opts{name};
    return 0 unless $name;
    my $desc = $opts{desc};
    my $link = $opts{link};

    my $ds = $coge->resultset('DataSource')->find($dsid);
    $ds->name($name);
    $ds->description($desc) if $desc;
    $ds->link($link) if ($link);
    $ds->update;

    return 1;
}

sub gen_html {
    my $html;
    my $template =
      HTML::Template->new( filename => $P->{TMPLDIR} . 'generic_page.tmpl' );
    $template->param( HELP => '/wiki/index.php?title=Lists' );
    my $name = $USER->user_name;
    $name = $USER->first_name if $USER->first_name;
    $name .= " " . $USER->last_name if $USER->first_name && $USER->last_name;
    $template->param( USER       => $name );
    $template->param( TITLE      => qq{} );
    $template->param( PAGE_TITLE => qq{Sources} );
    $template->param( LOGO_PNG   => "SourceView-logo.png" );
    $template->param( LOGON      => 1 ) unless $USER->user_name eq "public";
    $template->param( BODY       => gen_body() );

    #$template->param( BOX_NAME   => " Data Sources:" );
    #$template->param( ADJUST_BOX => 1 );
    $html .= $template->output;
}

sub gen_body {
    my $template =
      HTML::Template->new( filename => $P->{TMPLDIR} . 'Sources.tmpl' );
    $template->param( PAGE_NAME   => $FORM->url );
    $template->param( MAIN        => 1 );
    $template->param( SOURCE_INFO => get_sources() );
    $template->param( BUTTONS     => $USER->is_admin );
    $template->param( ADMIN_AREA  => $USER->is_admin );
    return $template->output;
}
