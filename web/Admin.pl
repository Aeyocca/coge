#! /usr/bin/perl -w

use strict;
use CGI;
use CoGe::Accessory::Web;
use HTML::Template;
use JSON qw(encode_json);
use Data::Dumper;
use List::Compare;
no warnings 'redefine';

use vars qw($P $PAGE_NAME $USER $BASEFILE $coge $cogeweb %FUNCTION $FORM $MAX_SEARCH_RESULTS);

$FORM = new CGI;
( $coge, $USER, $P ) = CoGe::Accessory::Web->init( cgi => $FORM );

$MAX_SEARCH_RESULTS = 400;

%FUNCTION = (
    search_organisms     => \&search_organisms,
    search_users	 => \&search_users,
    search_stuff	 => \&search_stuff,
);

CoGe::Accessory::Web->dispatch( $FORM, \%FUNCTION, \&gen_html );

sub gen_html {
    my $html;
    my $template =
      HTML::Template->new( filename => $P->{TMPLDIR} . 'generic_page.tmpl' );
    $template->param( HELP => '/wiki/index.php?title=ADMIN' );
    my $name = $USER->user_name;
    $name = $USER->first_name if $USER->first_name;
    $name .= " " . $USER->last_name if $USER->first_name && $USER->last_name;
    $template->param( USER       => $name );
    $template->param( PAGE_TITLE => qq{Admin} );
    $template->param( LOGO_PNG   => "Admin-logo.png" );
    $template->param( LOGON      => 1 ) unless $USER->user_name eq "public";
    $template->param( BODY       => gen_body() );
    $template->param( ADJUST_BOX => 1 );
    $html .= $template->output;
}

sub gen_body {
    unless ( $USER->is_admin ) {
        my $template =
          HTML::Template->new( filename => $P->{TMPLDIR} . "Admin.tmpl" );
        $template->param( ADMIN_ONLY     => 1 );
        return $template->output;
    }

    my $template =
      HTML::Template->new( filename => $P->{TMPLDIR} . 'Admin.tmpl' );
    $template->param( MAIN => 1);
    return $template->output;
}

sub search_stuff {
    my %opts        = @_;
    my $search_term = $opts{search_term};
    my $timestamp   = $opts{timestamp};

    my @searchArray = split(' ', $search_term );
    my @specialTerms;
    my @idList;
    my @results;
    #return unless $search_term;


    #Set up the necessary arrays of serch terms and special conditions
    for (my $i = 0; $i < @searchArray; $i++) {
	if (index($searchArray[$i], ':') == -1) {
		$searchArray[$i] = {'like', '%' . $searchArray[$i] . '%'};
	} else {
		my @splitTerm = split(':', $searchArray[$i] );
		splice(@searchArray, $i, 1);
		$i--; 
		push @specialTerms, { 'tag' => $splitTerm[0], 'term' => $splitTerm[1]};
	}		
    }
    #say STDERR Dumper(\@searchArray);
	
    #Set the special conditions
    my $type = "none";
    my @restricted = [-or => [restricted => 0, restricted => 1]];
    my @deleted = [deleted => 0];
    for (my $i = 0; $i < @specialTerms; $i++) {
	if ($specialTerms[$i]{tag} eq 'type') {
		$type = $specialTerms[$i]{term};
	}
	if ($specialTerms[$i]{tag} eq 'restricted') {
		@restricted = [restricted => $specialTerms[$i]{term}];
		if($type eq "none") {
			$type = 'restricted';
		}
	}
	if ($specialTerms[$i]{tag} eq 'deleted' && ($specialTerms[$i]{term} eq '0' || $specialTerms[$i]{term} eq '1')) {
                @deleted = [deleted => $specialTerms[$i]{term}];
		if($type eq "none") {
                        $type = 'deleted';
                }
        }
	if ($specialTerms[$i]{tag} eq 'deleted' && $specialTerms[$i]{term} eq '*') {
                @deleted = [-or => [deleted => 0, deleted => 1]];
		if($type eq "none") {
                        $type = 'deleted';
                }
        }
    }

    # Perform organism search
    if($type eq 'none' || $type eq 'organism' || $type eq 'genome' || $type eq 'restricted' || $type eq 'deleted') {
    	my @orgArray;
    	for (my $i = 0; $i < @searchArray; $i++) {
		push @orgArray, [-or => [name => $searchArray[$i], description => $searchArray[$i], organism_id => $searchArray[$i]]];
    	}
    	my @organisms = $coge->resultset("Organism")->search({
		-and => [
			@orgArray,
	    	],			
	});


    	if($type eq 'none' || $type eq 'organism') {
		foreach ( sort { $a->name cmp $b->name } @organisms ) {
        		push @results, { 'type' => "organism", 'label' => $_->name, 'id' => $_->id };
    		}
	}
    	@idList = map {$_->id} @organisms;
    }

    # Perform user search
    if($type eq 'none' || $type eq 'user') {
	my @usrArray;
    	for (my $i = 0; $i < @searchArray; $i++) {
        	push @usrArray, [-or => [user_name => $searchArray[$i], first_name =>  $searchArray[$i], user_id => $searchArray[$i], first_name =>  $searchArray[$i]]];
    	}
    	my @users = $coge->resultset("User")->search({
        	-and => [
            		@usrArray,
        	],
    	});

    	foreach ( sort { $a->user_name cmp $b->user_name } @users ) {
		push @results, { 'type' => "user", 'label' => $_->user_name, 'id' => $_->id };
    	}
    }

    # Perform genome search (corresponding to Organism results)
    if($type eq 'none' || $type eq 'genome' || $type eq 'restricted' || $type eq 'deleted') {
    	my @genomes = $coge->resultset("Genome")->search({
    		-and => [
			organism_id => {-in => \@idList },
			@restricted,
			@deleted,
		],
   	});
    
   	foreach ( sort { $a->id cmp $b->id } @genomes ) {
    		push @results, { 'type' => "genome", 'label' => $_->info, 'id' => $_->id };
    	}

    	# Perform direct genome search (by genome ID)
    	my @genIDArray;
    	for (my $i = 0; $i < @searchArray; $i++) {
        	push @genIDArray, [-or => [genome_id => $searchArray[$i]]];
    	}
    	my @genomeIDs = $coge->resultset("Genome")->search({
        	-and => [
            		@genIDArray,
	    		@restricted,
			@deleted,
        	],
    	});

    	foreach ( sort { $a->id cmp $b->id } @genomeIDs ) {
		push @results, { 'type' => "genome", 'label' => $_->info, 'id' => $_->id };
    	}
    }


    # Perform experiment search
    if($type eq 'none' || $type eq 'experiment' || $type eq 'restricted' || $type eq 'deleted') {
	my @expArray;
    	for (my $i = 0; $i < @searchArray; $i++) {
        	push @expArray, [-or => [name => $searchArray[$i], description =>  $searchArray[$i], experiment_id => $searchArray[$i]]];
    	}
    	my @experiments = $coge->resultset("Experiment")->search({
            	-and => [
                	@expArray,
			@restricted,
			@deleted,
            	],
        });

	foreach ( sort { $a->name cmp $b->name } @experiments ) {
        	push @results, { 'type' => "experiment", 'label' => $_->name, 'id' => $_->id };
    	}
    }


    # Perform notebook search
    if($type eq 'none' || $type eq 'notebook' || $type eq 'restricted' || $type eq 'deleted') {
	my @noteArray;
    	for (my $i = 0; $i < @searchArray; $i++) {
        	push @noteArray, [-or => [name => $searchArray[$i], description =>  $searchArray[$i], list_id => $searchArray[$i]]];
    	}
    	my @notebooks = $coge->resultset("List")->search({
            	-and => [
                	@noteArray,
			@restricted,
			@deleted,
            	],
        });

    	foreach ( sort { $a->name cmp $b->name } @notebooks ) {
        	push @results, { 'type' => "notebook", 'label' => $_->name, 'id' => $_->id };
    	}
    }


    # Perform user group search
    if($type eq 'none' || $type eq 'usergroup' || $type eq 'deleted') {
	my @usrGArray;
    	for (my $i = 0; $i < @searchArray; $i++) {
        	push @usrGArray, [-or => [name => $searchArray[$i], description =>  $searchArray[$i], user_group_id => $searchArray[$i]]];
    	}
    	my @userGroup = $coge->resultset("UserGroup")->search({
            	-and => [
                	@usrGArray,
			@deleted,
            	],
        });

    	foreach ( sort { $a->name cmp $b->name } @userGroup ) {
        	push @results, { 'type' => "user_group", 'label' => $_->name, 'id' => $_->id };
    	}
    }

    return encode_json( { timestamp => $timestamp, items => \@results } );
}

#Evan's modular stuff
#sub search_genomem {
#	# terms is an any array ference tags is a hash references
#	my ($terms, $tags, $organism_rs) = @_;
#
#	my @relevant_fields = qw(name description restricted access_count):
#
#	%organisms_tags{@relevant_fields} = $tags->{@relevant_fields};
#	$organism_tags = # ... filters tags to only organism search
#
#	my $search1 = $coge->resultset("Organism")->search({
#		-or {
#			-and {
#				create_like_fields($terms)
#			},
#			$organism_tags
#		}
#	}) ;
#
#	# Query only if organism rs exists
#	my $search2 = $organism_rs->dosomething if $organism_rs;
#
#	return join $search1 $search2;
#}

#sub search_users {
#    my %opts        = @_;
#    my $search_term = $opts{search_term};
#    my $timestamp   = $opts{timestamp};
#
#    #print STDERR "$search_term $timestamp\n";
#    return unless $search_term;
#
#    # Perform search
#    $search_term = '%' . $search_term . '%';
#    my @users = $coge->resultset("User")->search(
#        \[
#            'user_name LIKE ? OR first_name LIKE ? OR last_name LIKE ?',
#            [ 'user_name',  $search_term ],
#            [ 'first_name', $search_term ],
#            [ 'last_name',  $search_term ]
#        ]
#    );
#
#    # Limit number of results displayed
#    # if (@users > $MAX_SEARCH_RESULTS) {
#    # 	return encode_json({timestamp => $timestamp, items => undef});
#    # }
#
#    return encode_json(
#        {
#            timestamp => $timestamp,
#            items     => [ sort map { $_->user_name } @users ]
#        }
#    );
#}
