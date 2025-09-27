# SUSE's openQA tests
#
# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper class for Google Cloud Platform Computer Engine
#
# Maintainer: QE-C team <qa-c@suse.de>

package publiccloud::gce;
use Mojo::Base 'publiccloud::provider';
use Mojo::Util qw(trim);
use Mojo::JSON 'decode_json';
use testapi;
use utils;
use publiccloud::ssh_interactive 'select_host_console';
use DateTime;

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

sub get_gcp_guest_os_features {
    my ($self, $file) = @_;

    my %guest_os_features = (
        'SLES12-SP5' => [
            'GVNIC',
            'UEFI_COMPATIBLE',
            'VIRTIO_SCSI_MULTIQUEUE',
        ],
        'SLES15-SP2' => [
            'GVNIC',
            'SEV_CAPABLE',
            'UEFI_COMPATIBLE',
            'VIRTIO_SCSI_MULTIQUEUE',
        ],
        'SLES15-SP3' => [
            'GVNIC',
            'SEV_CAPABLE',
            'UEFI_COMPATIBLE',
            'VIRTIO_SCSI_MULTIQUEUE',
        ],
        'SLES15-SP4' => [
            'GVNIC',
            'IDPF',
            'SEV_CAPABLE',
            'SEV_LIVE_MIGRATABLE',
            'SEV_LIVE_MIGRATABLE_V2',
            'SEV_SNP_CAPABLE',
            'UEFI_COMPATIBLE',
            'VIRTIO_SCSI_MULTIQUEUE',
        ],
        'SLES15-SP5' => [
            'GVNIC',
            'IDPF',
            'SEV_CAPABLE',
            'SEV_LIVE_MIGRATABLE',
            'SEV_LIVE_MIGRATABLE_V2',
            'SEV_SNP_CAPABLE',
            'UEFI_COMPATIBLE',
            'VIRTIO_SCSI_MULTIQUEUE',
        ],
        'SLES15-SP6' => [
            'GVNIC',
            'IDPF',
            'SEV_CAPABLE',
            'SEV_LIVE_MIGRATABLE',
            'SEV_LIVE_MIGRATABLE_V2',
            'SEV_SNP_CAPABLE',
            'TDX_CAPABLE',
            'UEFI_COMPATIBLE',
            'VIRTIO_SCSI_MULTIQUEUE',
        ],
        'SLES15-SP7' => [
            'GVNIC',
            'IDPF',
            'SEV_CAPABLE',
            'SEV_LIVE_MIGRATABLE',
            'SEV_LIVE_MIGRATABLE_V2',
            'SEV_SNP_CAPABLE',
            'TDX_CAPABLE',
            'UEFI_COMPATIBLE',
            'VIRTIO_SCSI_MULTIQUEUE',
        ],
        'SLES-16.0' => [
            'GVNIC',
            'IDPF',
            'SEV_CAPABLE',
            'SEV_LIVE_MIGRATABLE',
            'SEV_LIVE_MIGRATABLE_V2',
            'SEV_SNP_CAPABLE',
            'TDX_CAPABLE',
            'UEFI_COMPATIBLE',
            'VIRTIO_SCSI_MULTIQUEUE',
        ],
    );

    my $os_version;
    if ($file =~ /SLES\d+-SP\d+|SLES-\d+\.\d+/i) {
        $os_version = uc($&);
    }

    die "Unsupported OS: $os_version" unless ($os_version && exists $guest_os_features{$os_version});

    return join(',', @{$guest_os_features{$os_version}});
}


sub upload_img {
    my ($self, $file) = @_;
    my $img_name = $self->file2name($file);
    my $uri = $self->provider_client->storage_name . '/' . $file;
    # See https://cloud.google.com/sdk/gcloud/reference/compute/images/create for a list of available features
    # SEV_CAPABLE is added because all images from 15-SP2 onwards support SEV

    my $guest_os_features = get_var('PUBLIC_CLOUD_GCE_UPLOAD_GUEST_FEATURES', $self->get_gcp_guest_os_features($file));
    my $arch = get_var('PUBLIC_CLOUD_ARCH', '');

    assert_script_run("gsutil cp '$file' 'gs://$uri'", timeout => 60 * 60);

    my $cmd = "gcloud compute images create '$img_name' --source-uri 'gs://$uri'";
    $cmd .= " --guest-os-features '$guest_os_features'" unless (trim($guest_os_features) eq '');
    if ($arch) {
        # Acceptable values are ARM64 and X86_64 (case sensitive).
        # We need to uppercase the value, as we typically use lowercase settings (e.g. arm64)
        $cmd .= " --architecture=" . uc $arch;
    }
    $cmd .= " --labels pcw_ignore=1" if (check_var('PUBLIC_CLOUD_KEEP_IMG', '1'));
    assert_script_run($cmd, timeout => 60 * 10);

    if (!$self->find_img($file)) {
        die("Cannot find image after upload!");
    }
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
    my @instances = $self->SUPER::terraform_apply(%args);

    my $instance_id = $self->get_terraform_output(".vm_name.value[0]");
    # gce provides full serial log, so extended timeout
    if (!check_var('PUBLIC_CLOUD_SLES4SAP', 1) && defined($instance_id)) {
        if ($instance_id !~ /$self->{resource_name}/) {
            record_info("Warn", "instance_id " . ($instance_id) ? $instance_id : "empty", result => 'fail');
        }
    }

    return @instances;
}

sub on_terraform_apply_timeout {
    my ($self) = @_;
}

sub upload_boot_diagnostics {
    my ($self, %args) = @_;
    my $region = $self->get_terraform_output('.region.value');
    my $availability_zone = $self->get_terraform_output('.availability_zone.value');
    my $project = $self->get_terraform_output('.project.value');
    my $instance_id = $self->get_terraform_output(".vm_name.value[0]");
    return if (check_var('PUBLIC_CLOUD_SLES4SAP', 1));
    unless (defined($instance_id) && defined($region) && defined($availability_zone)) {
        record_info('UNDEF. diagnostics', 'upload_boot_diagnostics: on gce, undefined instance or region or availability zone');
        return;
    }
    my $dt = DateTime->now;
    my $time = $dt->hms;
    $time =~ s/:/-/g;
    my $asset_path = "/tmp/console-$time.txt";
    # gce provides full serial log, so extended timeout
    script_run("gcloud compute --project=$project instances get-serial-port-output $instance_id --zone=$region-$availability_zone --port=1 > $asset_path", timeout => 180);
    if (script_output("du $asset_path | cut -f1") < 8) {
        record_info('Invalid screenshot', 'The console screenshot is invalid.');
        record_info($asset_path, script_output("cat $asset_path"));
    } else {
        upload_logs("$asset_path", failok => 1);
    }
}

# In GCE we need to account for project name, if given
sub get_image_id {
    my ($self, $img_url) = @_;
    my $image = $self->SUPER::get_image_id($img_url);
    my $project = get_var('PUBLIC_CLOUD_IMAGE_PROJECT');
    $image = "$project/$image" if ($project);
    return $image;
}

sub describe_instance {
    my ($self, $instance_id, $query) = @_;

    return script_output("gcloud compute instances list --filter=\"name=( 'NAME' '$instance_id')\" --format json | jq -r '$query'", quiet => 1);
}

sub get_state_from_instance {
    my ($self, $instance) = @_;
    my $instance_id = $instance->instance_id();

    my $status = $self->describe_instance($instance_id, '.[0].status');
    die("Unable to get status") unless $status;
    return $status;
}

sub get_public_ip {
    my ($self) = @_;
    my $instance_id = $self->get_terraform_output(".vm_name.value[0]");

    my $natIP = $self->describe_instance($instance_id, '.[0].networkInterfaces[0].accessConfigs[0].natIP');
    die("Unable to get public_ip") unless $natIP;
    return $natIP;
}

sub stop_instance {
    my ($self, $instance) = @_;
    my $instance_id = $instance->instance_id();
    my $attempts = 60;

    die('Outdated instance object') if ($self->get_public_ip() ne $instance->public_ip);

    assert_script_run("gcloud compute instances stop $instance_id --async", quiet => 1);
    while ($self->get_state_from_instance($instance) ne 'TERMINATED' && $attempts-- > 0) {
        sleep 5;
    }
    die("Failed to stop instance $instance_id") unless ($attempts > 0);
}

sub suspend_instance {
    my ($self, $instance) = @_;
    my $instance_id = $instance->instance_id();

    die("Cannot suspend instance which is not running.") if (lc($self->get_state_from_instance($instance)) ne 'running');
    assert_script_run("gcloud compute instances suspend $instance_id", timeout => 3600);
    $instance->wait_for_state('suspended');
}

sub resume_instance {
    my ($self, $instance) = @_;
    my $instance_id = $instance->instance_id();

    die("Cannot resume instance which is not suspended.") if (lc($self->get_state_from_instance($instance)) ne 'suspended');
    assert_script_run("gcloud compute instances resume $instance_id", timeout => 3600);
    $instance->wait_for_state('running');
}

sub start_instance {
    my ($self, $instance, %args) = @_;
    my $instance_id = $instance->instance_id();
    my $attempts = 60;

    die("Try to start a running instance") if ($self->get_state_from_instance($instance) ne 'TERMINATED');

    assert_script_run("gcloud compute instances start $instance_id --async", quiet => 1);
    while ($self->get_state_from_instance($instance) eq 'TERMINATED' && $attempts-- > 0) {
        sleep 1;
    }
    $instance->public_ip($self->get_public_ip());
}

sub teardown {
    my ($self, $args) = @_;
    $self->SUPER::teardown();
    return 1;
}

sub query_metadata {
    my ($self, $instance, %args) = @_;

    # Cloud metadata service API is reachable at local destination
    # 169.254.169.254 in case of all public cloud providers.
    my $pc_meta_api_ip = '169.254.169.254';

    my $query_meta_ipv4_cmd = qq(curl -sw "\\n" -H "Metadata-Flavor: Google" "http://$pc_meta_api_ip/computeMetadata/v1/instance/network-interfaces/0/ip");
    my $data = $instance->ssh_script_output($query_meta_ipv4_cmd);

    return $data;
}

1;
