# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create VM in GCP using gcloud binary
# We currently don't package gcloud binary
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use registration;
use testapi;
use serial_terminal 'select_serial_terminal';
use mmapi 'get_current_job_id';
use utils qw(zypper_call script_retry);
use version_utils 'is_sle';

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;
    my $job_id = get_current_job_id();

    # If 'gcloud' is preinstalled, we test that version
    if (script_run("which gcloud") != 0) {
        zypper_call 'in ntp' unless is_sle '=15-SP4';
        # We don't currently package 'gcloud' so we download the binary from upstream
        my $url = "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-387.0.0-linux-x86_64.tar.gz";
        assert_script_run "curl $url -o google-cloud-sdk.tar.gz";
        assert_script_run "tar xvf google-cloud-sdk.tar.gz";
        assert_script_run "google-cloud-sdk/install.sh --quiet --usage-reporting false --command-completion true";

        # The 'gcloud' binary in not in $PATH by default
        assert_script_run "echo 'source /root/google-cloud-sdk/completion.bash.inc' >> ~/.bashrc";
        assert_script_run "echo 'source ~/google-cloud-sdk/path.bash.inc' >> ~/.bashrc";
        assert_script_run "source ~/.bashrc";
    }

    set_var 'PUBLIC_CLOUD_PROVIDER' => 'GCE';
    my $provider = $self->provider_factory();
    assert_script_run "gcloud config set disable_usage_reporting false";
    assert_script_run "gcloud config set compute/zone europe-west4-a";

    my $machine_name = "openqa-cli-test-vm-$job_id";
    my $openqa_ttl = get_var('MAX_JOB_TIME', 7200) + get_var('PUBLIC_CLOUD_TTL_OFFSET', 300);
    my $openqa_hostname = get_required_var('OPENQA_HOSTNAME');
    $openqa_hostname =~ tr/./-/;
    # Only hyphens (-), underscores (_), lowercase characters, and numbers are allowed.
    my $labels = "openqa-cli-test-label=$job_id,openqa_created_by=$openqa_hostname,openqa_ttl=$openqa_ttl";
    my $metadata = 'ssh-keys=susetest:$(cat ~/.ssh/id_rsa.pub | sed "s/[[:blank:]]*$//") susetest';
    my $create_instance = "gcloud compute instances create $machine_name --image-family=sles-15 --image-project=suse-cloud";
    $create_instance .= " --machine-type=e2-micro --labels='$labels' --metadata=\"$metadata\"";
    assert_script_run($create_instance, 600);
    assert_script_run("gcloud compute instances list | grep '$machine_name'");

    # Check that the machine is reachable via ssh
    my $ip_address = script_output("gcloud compute instances describe $machine_name --format='get(networkInterfaces[0].accessConfigs[0].natIP)'", 90);
    script_retry("ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no susetest\@$ip_address hostnamectl", timeout => 90, delay => 15, retry => 12);
}

sub cleanup {
    my $job_id = get_current_job_id();
    my $machine_name = "openqa-cli-test-vm-$job_id";
    script_run("gcloud compute instances list | grep '$machine_name'");
    assert_script_run("gcloud compute instances stop $machine_name --zone=europe-west4-a", 240);
    assert_script_run("gcloud compute instances delete $machine_name --zone=europe-west4-a --delete-disks=all --quiet", 240);
}

sub test_flags {
    return {fatal => 0, milestone => 0, always_rollback => 1};
}

1;

