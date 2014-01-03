#!/usr/bin/perl -w

use AuthCAS;
use strict;
use CGI;
use CGI::Cookie;
use CGI::Carp 'fatalsToBrowser';
use HTML::Template;
use Data::Dumper;
use CGI::Log;
use CoGeX;
use CoGe::Accessory::Web;
use CoGe::Accessory::Utils qw( units commify );
use POSIX 'ceil';

no warnings 'redefine';
use vars qw($P $USER $FORM $coge $LINK);

$FORM = new CGI;
( $coge, $USER, $P, $LINK ) = CoGe::Accessory::Web->init( cgi => $FORM );

#logout is only called through this program!  All logouts from other pages are redirected to this page
CoGe::Accessory::Web->logout_cas(
    cookie_name => $P->{COOKIE_NAME},
    coge        => $coge,
    user        => $USER,
    form        => $FORM
) if $FORM->param('logout');

my %FUNCTION = ( get_latest_genomes => \&get_latest_genomes );

CoGe::Accessory::Web->dispatch( $FORM, \%FUNCTION, \&generate_html );

sub generate_html {
    my $template =
      HTML::Template->new( filename => $P->{TMPLDIR} . 'generic_page.tmpl' );
    my $name = $USER->user_name;
    $name = $USER->first_name if $USER->first_name;
    $name .= " " . $USER->last_name if $USER->first_name && $USER->last_name;

    $template->param(
        TITLE =>
'Accelerating <span style="color: #119911">Co</span>mparative <span style="color: #119911">Ge</span>nomics',
        PAGE_TITLE => 'Comparative Genomics',
        PAGE_LINK  => $LINK,
        HELP       => '/wiki/index.php',
        USER       => $name,
        ADJUST_BOX => 1,
        LOGO_PNG   => "CoGe-logo.png",
        BODY       => generate_body(),
    );

    $template->param( LOGON => 1 ) unless $USER->user_name eq "public";

    return $template->output;
}

sub generate_body {
    my $tmpl = HTML::Template->new( filename => $P->{TMPLDIR} . 'index.tmpl' );
    my $html;

    #    elsif ($USER && !$FORM->param('logout') && !$FORM->param('login'))
    #      {
    $tmpl->param(
        ACTIONS => [
            map {
                {
                    ACTION => $_->{NAME},
                    DESC   => $_->{DESC},
                    LINK   => $_->{LINK}
                }
              } sort { $a->{ID} <=> $b->{ID} } @{ actions() }
        ]
    );
    $tmpl->param(
        'INTRO'   => 1,
        ORG_COUNT => commify( $coge->resultset('Organism')->count() ),
        GEN_COUNT => commify(
            $coge->resultset('Genome')->search( { deleted => 0 } )->count()
        ),
#        NUCL_COUNT => .'('.commify(
#            units(
#                $coge->resultset('GenomicSequence')
#                  ->get_column('sequence_length')->sum
#              )
#              . 'bp)'
#        ),
        FEAT_COUNT => commify( $coge->resultset('Feature')->count() ),
        ANNOT_COUNT =>
          commify( $coge->resultset('FeatureAnnotation')->count() ),
        EXP_COUNT => commify(
            $coge->resultset('Experiment')->search( { deleted => 0 } )->count()
        ),
        QUANT_COUNT => commify(
            units(
                $coge->resultset('Experiment')->search( { deleted => 0 } )
                  ->get_column('row_count')->sum
            )
        )
    );

    #      }
    #    my $url = $FORM->param('url') if $FORM->param('url');
    #    if ($url)
    #     {
    #        $url =~ s/:::/;/g if $url;
    #        $tmpl->param(URL=>$url);
    #     }
    $html .= $tmpl->output;
    return $html;
}

sub actions {
    my @actions = (
        {
            ID => 6,
            LOGO =>
qq{<a href="./GEvo.pl"><img src="picts/carousel/GEvo-logo.png" width="227" height="75" border="0"></a>},
            ACTION => qq{<a href="./GEvo.pl">GEvo</a>},
            LINK   => qq{./GEvo.pl},
            DESC =>
qq{Compare sequences and genomic regions to discover patterns of genome evolution.  <a href ="GEvo.pl?prog=blastz;accn1=at1g07300;fid1=4091274;dsid1=556;chr1=1;dr1up=20000;dr1down=20000;gbstart1=1;gblength1=772;accn2=at2g29640;fid2=4113333;dsid2=557;chr2=2;dr2up=20000;dr2down=20000;gbstart2=1;rev2=1;num_seqs=2;autogo=1" target=_new>Example.</a>},
            SCREENSHOT =>
qq{<a href="./GEvo.pl"><img src="picts/preview/GEvo.png"border="0"></a>},
            NAME =>
qq{<span style="display:inline-block;width:100px;">GEvo</span><span style="font-weight:normal;">High-resolution sequence analysis of genomic regions</span>},
        },
        {
            ID => 3,
            LOGO =>
qq{<a href="./FeatView.pl"><img src="picts/carousel/FeatView-logo.png" width="227" height="75" border="0"></a>},
            ACTION => qq{<a href="./FeatView.pl">FeatView</a>},
            LINK   => qq{./FeatView.pl},
            DESC =>
qq{Find and display information about a genomic feature (e.g. gene). <a href = "FeatView.pl?accn=at1g07300" target=_new>Example.</a>},
            SCREENSHOT =>
qq{<a href="./FeatView.pl"><img src="picts/preview/FeatView.png" width="400" height="241" border="0"></a>},
            NAME =>
qq{<span style="display:inline-block;width:100px;">FeatView</span><span style="font-weight:normal;">Search for genomic features by name</span>},
        },

# 		   {
# 		    ID=>3,
# 		    LOGO=>qq{<a href="./MSAView.pl"><img src="picts/carousel/MSAView-logo.png" width="227" height="75" border="0"></a>},
# 		    ACTION => qq{<a href="./MSAView.pl">MSAView: Multiple Sequence Alignment Viewer</a>},
# 		    DESC   => qq{Allows users to submit a multiple sequence alignment in FASTA format (if people would like additional formats, please request via e-mail) in order to quickly check the alignment, find conserved regions, etc.  This program also generates a consensus sequence from the alignment and displays some basic statistics about the alignment.},
# 		    SCREENSHOT=>qq{<a href="./MSAView.pl"><img src="picts/preview/MSAView.png"border="0"></a>},
# 		   },
# 		   {
# 		    ID=>4,
# 		    LOGO=>qq{<a href="./TreeView.pl"><img src="picts/carousel/TreeView-logo.png" width="227" height="75" border="0"></a>},
# 		    ACTION => qq{<a href="./TreeView.pl">TreeView: Phylogenetic Tree Viewer</a>},
# 		    DESC   => qq{Allows users to submit a tree file and get a graphical view of their tree.  There is support for drawing rooted and unrooted trees, zooming and unzooming functions, and coloring and shaping nodes based on user specifications.},
# 		    SCREENSHOT=>qq{<a href="./FeatView.pl"><img src="picts/preview/TreeView.png"border="0"></a>},
# 		   },
        {
            ID => 1,
            LOGO =>
qq{<a href="./OrganismView.pl"><img src="picts/carousel/OrganismView-logo.png" width="227" height="75" border="0"></a>},
            ACTION => qq{<a href="./OrganismView.pl">OrganismView</a>},
            LINK   => qq{./OrganismView.pl},
            DESC =>
qq{Search for organisms, get an overview of their genomic make-up, and visualize them using a dynamic, interactive genome browser. <a href="OrganismView.pl?org_name=k12" target=_new>Example.</a>},
            SCREENSHOT =>
              qq{<img src="picts/preview/OrganismView.png" border="0"></a>},
            NAME =>
qq{<span style="display:inline-block;width:100px;">OrganismView</span><span style="font-weight:normal;">Search for organisms and perform analyses on their genomes</span>},
        },
        {
            ID => 2,
            LOGO =>
qq{<a href="./CoGeBlast.pl"><img src="picts/carousel/CoGeBlast-logo.png" width="227" height="75" border="0"></a>},
            ACTION => qq{<a href="./CoGeBlast.pl">CoGeBlast</a>},
            LINK   => qq{./CoGeBlast.pl},
            DESC =>
              qq{Blast sequences against any number of organisms in CoGe.},
            SCREENSHOT =>
qq{<a href="./CoGeBlast.pl"><img src="picts/preview/Blast.png" width="400" height="241" border="0"></a>},
            NAME =>
qq{<span style="display:inline-block;width:100px;">CoGeBlast</span><span style="font-weight:normal;">Blast sequences against any number of genomes of your choosing</span>},
        },

# 		   {
# 		    ID => 7,
# 		    LOGO => qq{<a href="./docs/help/CoGe"><img src="picts/carousel/FAQ-logo.png" width="227" height="75" border="0"></a>},
# 		    ACTION => qq{<a href="./docs/help/CoGe/">CoGe Faq</a>},
# 		    DESC   => qq{What is CoGe?  This document covers some of the basics about what CoGe is, how it has been designed, and other information about the system.},
# 		    SCREENSHOT => qq{<a href="./docs/help/CoGe"><img src="picts/preview/app_schema.png" border="0"></a>},
# 		   }
        {
            ID => 4,
            LOGO =>
qq{<a href="./SynMap.pl"><img src="picts/SynMap-logo.png"  border="0"></a>},
            ACTION => qq{<a href="./SynMap.pl">SynMap</a>},
            LINK   => qq{./SynMap.pl},
            DESC =>
qq{Compare any two genomes to identify regions of synteny.  <a href="SynMap.pl?dsgid1=3068;dsgid2=8;D=20;g=10;A=5;w=0;b=1;ft1=1;ft2=1;dt=geneorder;ks=1;autogo=1" target=_mew>Example.</a>  <span class=small>(Powered by <a href=http://dagchainer.sourceforge.net/ target=_new>DAGChainer</a></span>)},
            SCREENSHOT =>
qq{<a href="./SynMap.pl"><img src="picts/preview/SynMap.png" border="0" width="400" height="320"></a>},
            NAME =>
qq{<span style="display:inline-block;width:100px;">SynMap</span><span style="font-weight:normal;">Whole genome syntenic dotplot anlayses</span>},
        },
        {
            ID => 4,
            LOGO =>
qq{<a href="./SynFind.pl"><img src="picts/SynFind-logo.png"  border="0"></a>},
            ACTION => qq{<a href="./SynFind.pl">SynFind</a>},
            LINK   => qq{./SynFind.pl},
            SCREENSHOT =>
qq{<a href="./SynFind.pl"><img src="picts/preview/SynMap.png" border="0" width="400" height="320"></a>},
            NAME =>
qq{<span style="display:inline-block;width:100px;">SynFind</span><span style="font-weight:normal;">Identify syntenic regions across many genomes</span>},
        },
    );
    return \@actions;
}

sub get_latest_genomes {
    my %opts = @_;
    my $limit = $opts{limit} || 20;

    my @db = $coge->resultset("Genome")->search(
        {},
        {
            distinct => "organism.name",
            join     => "organism",
            prefetch => "organism",
            order_by => "genome_id desc",
            rows     => $limit * 10,
        }
    );

    #($USER) = CoGe::Accessory::LogUser->get_user();
    my $html = "<table class='small'>";
    $html .= "<tr><th>"
      . join( "<th>", qw( Organism &nbsp Length&nbsp(nt) &nbsp Related Link ) );
    my @opts;
    my %org_names;
    my $genome_count = 0;
    foreach my $dsg (@db) {
        next unless $USER->has_access_to_genome($dsg);
        next if $org_names{ $dsg->organism->name };
        last if $genome_count >= $limit;
        $org_names{ $dsg->organism->name } = 1;
        my $orgview_link = "OrganismView.pl?oid=" . $dsg->organism->id;
        my $entry        = qq{<tr>};

#$entry .= qq{<td><span class='ui-button ui-corner-all' onClick="window.open('$orgview_link')"><span class="ui-icon ui-icon-link"></span>&nbsp&nbsp</span>};
        $entry .=
          qq{<td><span class="link" onclick=window.open('$orgview_link')>};
        my $name = $dsg->organism->name;
        $name = substr( $name, 0, 40 ) . "..." if length($name) > 40;
        $entry .= $name;
        $entry .= qq{</span>};

        #$entry .= ": ".$dsg->name if $dsg->name;
        $entry .= "<td>(v" . $dsg->version . ")&nbsp";
        $entry .= "<td align=right>" . commify( $dsg->length ) . "<td>";
        my @desc = split( /;/, $dsg->organism->description );
        while ( $desc[0] && !$desc[-1] ) { pop @desc; }
        $desc[-1] =~ s/^\s+// if $desc[-1];
        $desc[-1] =~ s/\s+$// if $desc[-1];
        my $orgview_search = "OrganismView.pl?org_desc=" . $desc[-1];
        $entry .=
qq{<td><span class="link" onclick="window.open('$orgview_search')">Search</span>};
        $entry .= qq{<td>};
        $entry .=
qq{<img onClick="window.open('$orgview_link')" src="picts/other/CoGe-icon.png" title="CoGe" class="link">};

        my $search_term = $dsg->organism->name;
        $entry .=
qq{<img onclick="window.open('http://www.ncbi.nlm.nih.gov/taxonomy?term=$search_term')" src="picts/other/NCBI-icon.png" title="NCBI" class="link">};
        $entry .=
qq{<img onclick="window.open('http://en.wikipedia.org/w/index.php?title=Special%3ASearch&search=$search_term')" src="picts/other/wikipedia-icon.png" title="Wikipedia" class="link">};
        $search_term =~ s/\s+/\+/g;
        $entry .=
qq{<img onclick="window.open('http://www.google.com/search?q=$search_term')" src="picts/other/google-icon.png" title="Google" class="link">};
        $entry .= qq{</tr>};
        push @opts, $entry
          ; #, "<OPTION value=\"".$item->organism->id."\">".$date." ".$item->organism->name." (id".$item->organism->id.") "."</OPTION>";
        $genome_count++;
    }
    $html .= join "\n", @opts;
    $html .= "</table>";
    return $html;
}
