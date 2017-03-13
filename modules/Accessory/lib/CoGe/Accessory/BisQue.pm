package CoGe::Accessory::BisQue;

use v5.14;
use strict;
use warnings;

use Data::Dumper;
use File::Basename qw(basename dirname);
use File::Spec::Functions qw(catfile);
use HTTP::Request;

use CoGe::Accessory::IRODS qw(irods_get_base_path irods_imeta_ls irods_imkdir irods_iput irods_irm);
use CoGe::Accessory::Web qw(get_defaults);

BEGIN {
    our (@ISA, $VERSION, @EXPORT);
    require Exporter;

    $VERSION = 0.0.1;
    @ISA = qw(Exporter);
    @EXPORT = qw( create_bisque_image delete_bisque_image get_bisque_data_url set_bisque_visiblity );
}

sub create_bisque_image {
    my ($object, $upload, $user) = @_;

    my $target_type = lc(ref($object));
    warn $target_type;
    $target_type = 'notebook' if $target_type eq 'list';
    my $dest = _get_bisque_dir($target_type, $object->id, $user);
    irods_imkdir($dest);
    $dest = catfile($dest, basename($upload->filename));
    my $source;
    if ($upload->asset->is_file) {
         $source = $upload->asset->path;
    }
    else {
        $source = get_upload_path('coge', get_unique_id());
        system('mkdir', '-p', $source);
        $source = catfile($source, $upload->filename);
        $upload->asset->move_to($source);
    }
    irods_iput($source, $dest);
    for my $i (0..9) {
        sleep 5;
        my $result = irods_imeta_ls($dest, 'ipc-bisque-id');
        if (@$result == 4 && substr($result->[2], 0, 6) eq 'value:') {
            my $bisque_id = substr($result->[2], 7);
            chomp $bisque_id;
            _share_bisque_image($bisque_id, $user);
            return $bisque_id, $upload->filename;
        }
    }
    warn 'unable to get bisque id';
}

# object_type must be experiment, genome, or notebook
sub delete_bisque_image {
    my ($object_type, $object_id, $bisque_file, $bisque_id, $user) = @_;
    my $path = catfile(_get_bisque_dir($object_type, $object_id, $user), $bisque_file);
    my $res = irods_irm($path);
    my $ua = LWP::UserAgent->new();
    my $req = HTTP::Request->new(DELETE => 'https://bisque.cyverse.org/data_service/' . $bisque_id);
    $req->authorization_basic('coge', CoGe::Accessory::Web::get_defaults()->{BISQUE_PASS});
    $res = $ua->request($req);
}

sub get_bisque_data_url {
    my $id = shift;
    return 'https://bisque.cyverse.org/data_service/' . $id;
}

sub _get_bisque_dir {
    my ($target_type, $target_id, $user) = @_;
    return catfile(dirname(irods_get_base_path('coge')), 'bisque_data', $target_type, $target_id);
}

sub set_bisque_visiblity {
    my ($bisque_id, $public) = @_;
    my $ua = LWP::UserAgent->new();
    my $req = HTTP::Request->new(POST => 'https://bisque.cyverse.org/data_service/' . $bisque_id, ['Content-Type' => 'application/xml']);
    $req->authorization_basic('coge', CoGe::Accessory::Web::get_defaults()->{BISQUE_PASS});
    $req->content('<image permission="' . ($public ? 'published' : 'private') . '" />');
    my $res = $ua->request($req);
    warn Dumper $res->{_content};
}

sub _share_bisque_image {
    my ($bisque_id, $user) = @_;
    my $ua = LWP::UserAgent->new();
    my $req = HTTP::Request->new(GET => 'https://bisque.cyverse.org/data_service/user?resource_name=' . $user->name . '&wpublic=1');
    my $res = $ua->request($req);
    my $content = $res->{_content};
    my $index = index($content, 'resource_uniq="') + 15;
    if ($index != -1) {
        my $coge_user_uniq = substr($content, $index, index($content, '"', $index) - $index);
        $req = HTTP::Request->new(POST => 'https://bisque.cyverse.org/data_service/' . $bisque_id . '/auth?notify=false', ['Content-Type' => 'application/xml']);
        $req->authorization_basic('coge', CoGe::Accessory::Web::get_defaults()->{BISQUE_PASS});
        $req->content('<auth user="' . $coge_user_uniq . '" permission="edit" />');
        $res = $ua->request($req);
    }
}

1;
