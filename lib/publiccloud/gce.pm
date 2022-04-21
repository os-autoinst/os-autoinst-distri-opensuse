# SUSE's openQA tests
#
# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper class for Google Cloud Platform Computer Engine
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>
#             Jose Lausuch <jalausuch@suse.de>
#             qa-c team <qa-c@suse.de>

package publiccloud::gce;
use Mojo::Base 'publiccloud::provider';
use Mojo::Util qw(trim);
use Mojo::JSON 'decode_json';
use testapi;
use utils;

sub init {
    my ($self, %params) = @_;
    $self->SUPER::init();
    $self->provider_client(publiccloud::gcp_client->new());
    $self->provider_client->init();
}

sub file2name {
    my ($self, $file) = @_;
    my $name = $file;
    $name = lc $file;    # lower case
    $name =~ s/\.tar\.gz$//;    # removes tar.gz
    $name =~ s/\./-/g;
    $name =~ s/[^-a-z0-9]//g;    # only allowed characteres from Google Cloud
    return $name;
}

sub find_img {
    my ($self, $name) = @_;
    my $img_name = $self->file2name($name);
    my $out = script_output("gcloud --format json compute images list --filter='name~$img_name'", 10, proceed_on_failure => 1);
    return unless ($out);
    my $json = decode_json($out);
    return if (@{$json} == 0);
    return $json->[0]->{name};
}

sub upload_img {
    my ($self, $file) = @_;
    my $img_name = $self->file2name($file);
    my $uri = $self->provider_client->storage_name . '/' . $file;
    # See https://cloud.google.com/sdk/gcloud/reference/compute/images/create for a list of available features
    # SEV_CAPABLE is added because all images from 15-SP2 onwards support SEV
    my $guest_os_features = get_var('PUBLIC_CLOUD_GCE_UPLOAD_GUEST_FEATURES', 'MULTI_IP_SUBNET,UEFI_COMPATIBLE,VIRTIO_SCSI_MULTIQUEUE,SEV_CAPABLE');

    assert_script_run("gsutil cp '$file' 'gs://$uri'", timeout => 60 * 60);

    my $cmd = "gcloud compute images create '$img_name' --source-uri 'gs://$uri'";
    $cmd .= " --guest-os-features '$guest_os_features'" unless (trim($guest_os_features) eq '');
    assert_script_run($cmd, timeout => 60 * 10);

    if (!$self->find_img($file)) {
        die("Cannot find image after upload!");
    }
    return $img_name;
}

sub img_proof {
    my ($self, %args) = @_;

    $args{credentials_file} = $self->provider_client->get_credentials_file_name();
    $args{instance_type} //= 'n1-standard-2';
    $args{user} //= 'susetest';
    $args{provider} //= 'gce';

    return $self->run_img_proof(%args);
}

sub terraform_apply {
    my ($self, %args) = @_;
    $args{project} //= $self->provider_client->project_id;
    $args{confidential_compute} = get_var("PUBLIC_CLOUD_CONFIDENTIAL_VM", 0);
    return $self->SUPER::terraform_apply(%args);
}


# In GCE we need to account for project name, if given
sub get_image_id {
    my ($self, $img_url) = @_;
    my $image = $self->SUPER::get_image_id($img_url);
    my $project = get_var('PUBLIC_CLOUD_IMAGE_PROJECT');
    $image = "$project/$image" if ($project);
    return $image;
}

sub describe_instance
{
    my ($self, $instance) = @_;
    my $name = $instance->instance_id();
    my $attempts = 10;

    my $out = [];
    while (@{$out} == 0 && $attempts-- > 0) {
        $out = decode_json(script_output("gcloud compute instances list --filter=\"name=( 'NAME' '$name')\" --format json", quiet => 1));
        sleep 3;
    }

    die("Unable to retrive description of instance $name") unless ($attempts > 0);
    return $out->[0];
}

sub get_state_from_instance
{
    my ($self, $instance) = @_;
    my $name = $instance->instance_id();

    my $desc = $self->describe_instance($instance);
    die("Unable to get status") unless exists($desc->{status});
    return $desc->{status};
}

sub get_ip_from_instance
{
    my ($self, $instance) = @_;
    my $name = $instance->instance_id();

    my $desc = $self->describe_instance($instance);
    die("Unable to get public_ip") unless exists($desc->{networkInterfaces}->[0]->{accessConfigs}->[0]->{natIP});
    return $desc->{networkInterfaces}->[0]->{accessConfigs}->[0]->{natIP};
}

sub stop_instance
{
    my ($self, $instance) = @_;
    my $name = $instance->instance_id();
    my $attempts = 60;

    die('Outdated instance object') if ($self->get_ip_from_instance($instance) ne $instance->public_ip);

    assert_script_run("gcloud compute instances stop $name --async", quiet => 1);
    while ($self->get_state_from_instance($instance) ne 'TERMINATED' && $attempts-- > 0) {
        sleep 5;
    }
    die("Failed to stop instance $name") unless ($attempts > 0);
}

sub start_instance
{
    my ($self, $instance, %args) = @_;
    my $name = $instance->instance_id();
    my $attempts = 60;

    die("Try to start a running instance") if ($self->get_state_from_instance($instance) ne 'TERMINATED');

    assert_script_run("gcloud compute instances start $name --async", quiet => 1);
    while ($self->get_state_from_instance($instance) eq 'TERMINATED' && $attempts-- > 0) {
        sleep 1;
    }
    $instance->public_ip($self->get_ip_from_instance($instance));
}

sub cleanup {
    my ($self) = @_;
    $self->SUPER::cleanup();
    $self->provider_client->cleanup();
}

1;
