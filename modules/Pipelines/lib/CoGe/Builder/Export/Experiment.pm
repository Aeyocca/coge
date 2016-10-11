package CoGe::Builder::Export::Experiment;

use Moose;
with qw(CoGe::Builder::Buildable);

use CoGe::Accessory::IRODS qw(irods_get_base_path);
use CoGe::Accessory::Utils qw(sanitize_name);
use CoGe::Accessory::Web qw(download_url_for);
use CoGe::Core::Storage qw(get_experiment_cache_path);
use CoGe::Core::Experiment qw(get_irods_metadata);
use CoGe::Builder::CommonTasks qw(export_experiment_job export_to_irods);
use File::Spec::Functions qw(catdir catfile);
use Data::Dumper;

sub get_name {
    return "Export experiment";
}

sub build {
    my $self = shift;

    # Verify required parameters and set defaults
    my $dest_type = $self->params->{dest_type};
    $dest_type = "http" unless $dest_type;
    
    my $eid = $self->params->{eid} || $self->params->{experiment_id};
    return unless $eid;

    # Get experiment
    my $experiment = $self->db->resultset('Experiment')->find($eid);
    my $exp_name = sanitize_name($experiment->name);
       $exp_name = $eid unless $exp_name;

    my $output_file = "experiment_$exp_name.tar.gz";
    my $cache_dir = get_experiment_cache_path($eid);
    my $cache_file = catfile($cache_dir, $output_file);

    # Export experiment
    $self->workflow->add_job( 
        export_experiment_job(
            eid => $eid, 
            output => $cache_file
        )
    );

    my @done_files;
    if ($dest_type eq "irods") { # irods export
        # Set IRODS destination path
        my $irods_base = $self->params->{dest_path};
        $irods_base = irods_get_base_path($self->user->name) unless $irods_base;
        my $irods_dest = catfile($irods_base, $output_file);

        # Export file task
        $self->add_task_chain(
            $self->export_to_irods(
                src_file => $cache_file,
                dest_file => catfile($irods_base, $output_file),
                overwrite => $self->params->{overwrite}
            )
        );

        # Set file metadata task
        my $md = get_irods_metadata($experiment);
        my $md_file = catfile($self->staging_dir, 'irods_metadata.json');
        CoGe::Accessory::TDS::write($md_file, $md);
        $self->add_task_chain(
            $self->create_irods_imeta(
                dest_file => $irods_dest,
                metadata_file => $md_file
            )
        );

        # Add to results
        $self->add_task_chain(
            $self->add_result(
                result   => {
                    type => 'irods',
                    path => $irods_dest
                }
            )
        );
    } 
    else { # http download
        $self->add_task_chain(
            $self->add_result(
                result   => {
                    type => 'url',
                    path => download_url_for(
                        eid => $experiment->id,
                        file => $output_file
                    )
                }
            )
        );
    }
    
    return 1;
}

1;
