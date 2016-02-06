use Mojolicious::Lite;
use Mojo::Log;

# Set the module include path -- this is necessary to allow multiple sandboxes on dev
use lib './modules/perl';

# Set port -- each sandbox should be set to a unique port in Apache config and coge.conf
use CoGe::Accessory::Web qw(get_defaults);
my $port = get_defaults->{MOJOLICIOUS_PORT} || 3303;
print STDERR "CoGe API (port $port)\n";

# Setup Hypnotoad
app->config(hypnotoad => {listen => ["http://localhost:$port/"], proxy => 1});
app->log( Mojo::Log->new( path => "mojo.log", level => 'debug' ) ); # log in sandbox top-level directory

# mdb added 8/27/15 -- prevent "Your secret passphrase needs to be changed" message
#$self->secrets('coge'); # it's okay to have this secret in the code (rather the config file) because we don't use signed cookies

# Instantiate router
my $r = app->routes->namespaces(["CoGe::Services::Data"]);

# TODO: Authenticate user here instead of redundantly in each submodule
#    my $app = $self;
#    $self->hook(before_dispatch => sub {
#        my $c = shift;
#        # Authenticate user and connect to the database
#        my ($db, $user, $conf) = CoGe::Services::Auth::init($app);
#        $c->stash(db => $db, user => $user, conf => $conf);
#    });
    
# Global Search routes
$r->get("/global/search/#term")
    ->name("global-search")
    ->to("search#search", term => undef);

# Organism routes
$r->get("/organisms/search/#term")
    ->name("organisms-search")
    ->to("organism#search", term => undef);

$r->get("/organisms/:id" => [id => qr/\d+/])
    ->name("organisms-fetch")
    ->to("organism#fetch", id => undef);

$r->put("/organisms")
    ->name("organisms-add")
    ->to("organism#add");

# Genome routes
$r->get("/genomes/search/#term")
    ->name("genomes-search")
    ->to("genome2#search", term => undef);

$r->get("/genomes/:id" => [id => qr/\d+/])
    ->name("genomes-fetch")
    ->to("genome2#fetch", id => undef);
    
$r->put("/genomes")
    ->name("genomes-add")
    ->to("genome2#add");

# Dataset routes
#$r->get("/genomes/search/#term")
#    ->name("genomes-search")
#    ->to("genome2#search", term => undef);

$r->get("/datasets/:id" => [id => qr/\d+/])
    ->name("datasets-fetch")
    ->to("dataset#fetch", id => undef);

$r->get("/datasets/:id/genomes" => [id => qr/\d+/])
    ->name("datasets-genomes")
    ->to("dataset#genomes", id => undef);

# Feature routes
$r->get("/features/search/#term")
    ->name("features-search")
    ->to("feature2#search", term => undef);
    
$r->get("/features/:id" => [id => qr/\d+/])
    ->name("features-fetch")
    ->to("feature2#fetch", id => undef);
    
$r->get("/features/sequence/:id" => [id => qr/\d+/])
    ->name("features-sequence")
    ->to("feature2#sequence", id => undef);

# Experiment routes
$r->get("/experiments/search/#term")
    ->name("experiments-search")
    ->to("experiment#search", term => undef);

$r->get("/experiments/:id" => [id => qr/\d+/])
    ->name("experiments-fetch")
    ->to("experiment#fetch", id => undef);

$r->put("/experiments")
    ->name("experiments-add")
    ->to("experiment#add");

# Notebook routes
$r->get("/notebooks/search/#term")
    ->name("notebooks-search")
    ->to("notebook#search", term => undef);

$r->get("/notebooks/:id" => [id => qr/\d+/])
    ->name("notebooks-fetch")
    ->to("notebook#fetch", id => undef);
    
$r->put("/notebooks")
    ->name("notebooks-add")
    ->to("notebook#add");
    
$r->delete("/notebooks/:id" => [id => qr/\d+/])
    ->name("notebooks-remove")
    ->to("notebook#remove");

# User routes -- not documented, only for internal use
$r->get("/users/search/#term")
    ->name("users-search")
    ->to("user#search", term => undef);

#$r->get("/users/:id" => [id => qr/\w+/])
#    ->name("users-fetch")
#    ->to("user#fetch", id => undef);

$r->get("/users/:id/items" => [id => qr/\w+/])
    ->name("users-items")
    ->to("user#items", id => undef);

# User group routes
$r->get("/groups/search/#term")
    ->name("groups-search")
    ->to("group#search", term => undef);

$r->get("/groups/:id" => [id => qr/\d+/])
    ->name("groups-fetch")
    ->to("group#fetch", id => undef);

$r->get("/groups/:id/items" => [id => qr/\d+/])
    ->name("groups-items")
    ->to("group#items", id => undef);

# Job routes
$r->put("/jobs")
    ->name("jobs-add")
    ->to("job#add");

$r->get("/jobs/:id" => [id => qr/\d+/])
    ->name("jobs-fetch")
    ->to("job#fetch", id => undef);

$r->get("/jobs/:id/results/:name" => { id => qr/\d+/, name => qr/\w+/ })
    ->name("jobs-results")
    ->to("job#results", id => undef, name => undef);

# Log routes -- not documented, only for internal use
#$r->get("/logs/search/#term")
#    ->name("logs-search")
#    ->to("log#search", term => undef);
        
$r->get("/logs/:type/:id" => [type => qr/\w+/, id => qr/\d+/])
    ->name("logs-fetch")
    ->to("log#fetch", id => undef, type => undef);

# IRODS routes
$r->get("/irods/list/")
    ->name("irods-list")
    ->to("IRODS#list");
    
$r->get("/irods/list/(*path)")
    ->name("irods-list")
    ->to("IRODS#list");
        
# mdb removed 8/24/15 -- not used
#$r->get("/irods/fetch/(*path)")
#    ->name("irods-fetch")
#    ->to("IRODS#fetch");

# FTP routes
$r->get("/ftp/list/")
    ->name("ftp-list")
    ->to("FTP#list");
        
# Not found
$r->any("*" => sub {
    my $c = shift;
    $c->render(status => 404, json => { error => {Error => "Resource not found" }});
});

app->start;