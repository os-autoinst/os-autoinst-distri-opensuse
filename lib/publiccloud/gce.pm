# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Helper class for Google Cloud Platform
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>
#             Jose Lausuch <jalausuch@suse.de>

package publiccloud::gce;
use Mojo::Base 'publiccloud::provider';
use Mojo::Util 'b64_decode';
use Mojo::JSON 'decode_json';
use testapi;
use utils;

use constant CREDENTIALS_FILE => '/root/google_credentials.json';

has account             => undef;
has project_id          => undef;
has private_key_id      => undef;
has private_key         => undef;
has service_acount_name => undef;
has client_id           => undef;
has storage_name        => undef;

sub init {
    my ($self) = @_;
    $self->SUPER::init();

    $self->create_credentials_file();
    assert_script_run('source ~/.bashrc');
    assert_script_run('ntpdate -s time.google.com');
    assert_script_run('gcloud config set account ' . $self->account);
    assert_script_run('gcloud auth activate-service-account --key-file=' . CREDENTIALS_FILE . ' --project=' . $self->project_id);
}

sub create_credentials_file {
    my ($self) = @_;
    my $credentials_file;

    if ($self->private_key_id()) {
        $credentials_file = "{" . $/
          . '"type": "service_account", ' . $/
          . '"project_id": "' . $self->project_id . '", ' . $/
          . '"private_key_id": "' . $self->private_key_id . '", ' . $/
          . '"private_key": "' . $self->private_key . '", ' . $/
          . '"client_email": "' . $self->service_acount_name . '@' . $self->project_id . '.iam.gserviceaccount.com", ' . $/
          . '"client_id": "' . $self->client_id . '", ' . $/
          . '"auth_uri": "https://accounts.google.com/o/oauth2/auth", ' . $/
          . '"token_uri": "https://oauth2.googleapis.com/token", ' . $/
          . '"auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs", ' . $/
          . '"client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/' . $self->service_acount_name . '%40' . $self->project_id . '.iam.gserviceaccount.com"' . $/
          . '}';
    } else {
        record_info('INFO', 'Get credentials from VAULT server.');
        my $res = $self->vault_api('/v1/gcp/key/openqa-role', method => 'get');
        $credentials_file = b64_decode($res->{data}->{private_key_data});
        my $cf_json = decode_json($credentials_file);
        $self->account($cf_json->{client_email});
        $self->project_id($cf_json->{'project_id'});
        $self->vault_lease_id($res->{lease_id});
    }

    save_tmp_file(CREDENTIALS_FILE, $credentials_file);
    assert_script_run('curl -O ' . autoinst_url . "/files/" . CREDENTIALS_FILE);
}


sub file2name {
    my ($self, $file) = @_;
    my $name = $file;
    $name = lc $file;    # lower case
    $name =~ s/[^a-z0-9]//g;    # only allowed characteres from Google Cloud
    $name =~ s/targz$//;        # removes targz
    return $name;
}

sub find_img {
    my ($self, $name) = @_;
    my $img_name = $self->file2name($name);
    my $out      = script_output("gcloud compute images list --filter='name~$img_name'|grep -v NAME", 10, proceed_on_failure => 1);
    return if (!$out || $out =~ m/0 items/);
    my ($image) = $out =~ /(\w+)/;
    return $image;
}

sub upload_img {
    my ($self, $file, $type) = @_;
    my $img_name = $self->file2name($file);
    my $uri      = $self->storage_name . '/' . $file;
    $type //= 'default';
    assert_script_run("gsutil cp $file gs://$uri", timeout => 60 * 60);

    my $cmd = "gcloud compute images create $img_name --source-uri gs://$uri";
    if ($type eq 'uefi') {
        $cmd .= " --guest-os-features MULTI_IP_SUBNET,SECURE_BOOT,UEFI_COMPATIBLE,VIRTIO_SCSI_MULTIQUEUE";
    }
    assert_script_run($cmd, timeout => 60 * 10);

    if (!$self->find_img($file)) {
        die("Cannot find image after upload!");
    }
    return $img_name;
}

sub ipa {
    my ($self, %args) = @_;

    $args{credentials_file} = CREDENTIALS_FILE;
    $args{instance_type} //= 'n1-standard-2';
    $args{user}          //= 'susetest';
    $args{provider}      //= 'gce';

    return $self->run_ipa(%args);
}

sub describe_instance
{
    my ($self, $instance) = @_;
    my $name     = $instance->instance_id();
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
    my $name     = $instance->instance_id();
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
    my $name     = $instance->instance_id();
    my $attempts = 60;

    die("Try to start a running instance") if ($self->get_state_from_instance($instance) ne 'TERMINATED');

    assert_script_run("gcloud compute instances start $name --async", quiet => 1);
    while ($self->get_state_from_instance($instance) eq 'TERMINATED' && $attempts-- > 0) {
        sleep 1;
    }
    $instance->public_ip($self->get_ip_from_instance($instance));
}


1;
