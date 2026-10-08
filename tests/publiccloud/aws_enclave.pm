# SUSE's openQA tests
#
# Copyright @ SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: AWS Nitro enclave test
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use registration;
use testapi;
use utils;
use nvidia_utils;
use version_utils qw(is_sle is_sle_micro);
use Mojo::JSON qw(decode_json);

sub run {
    my ($self) = @_;
    my $instance = publiccloud::instances::get_instance();

    die "This module cannot run in TUNNELED mode" if (get_var("TUNNELED"));

    # Prepare system under test
    assert_script_run("curl -sf " . data_url('publiccloud/aws_nitro/Dockerfile') . " -o Dockerfile");
    assert_script_run("curl -sf " . data_url('publiccloud/aws_nitro/allocator.yaml') . " -o allocator.yaml");
    $instance->scp("Dockerfile", "remote:Dockerfile");    # upload always happens as ec2-user
    $instance->scp("allocator.yaml", "remote:allocator.yaml");
    $instance->ssh_assert_script_run("sudo install -D -m root -g root -m 0644 allocator.yaml /etc/nitro_enclaves/allocator.yaml");

    # Prepare instance
    $instance->ssh_script_retry("sudo zypper -n in docker aws-nitro-enclaves-cli", timeout => 300, retry => 3);
    $instance->ssh_assert_script_run("sudo systemctl enable --now docker.service");
    $instance->ssh_assert_script_run("sudo systemctl enable --now nitro-enclaves-allocator.service");
    $instance->ssh_script_retry("sudo systemctl is-active nitro-enclaves-allocator.service", retry => 5, delay => 60);

    # Build runtime container for the Nitro Enclave
    $instance->ssh_script_retry("sudo docker build -t enclave .", timeout => 300, retry => 3, delay => 120);
    $instance->ssh_assert_script_run("sudo nitro-cli build-enclave --docker-uri enclave --output-file /root/enclave-image.eif", timeout => 300);

    # Run the build Enclave
    $instance->ssh_assert_script_run("sudo nitro-cli run-enclave --cpu-count 2 --memory 512 --eif-path /root/enclave-image.eif --debug-mode", timeout => 300);

    # Get the Enclave console
    my $enclaves = $instance->ssh_script_output("sudo nitro-cli describe-enclaves");
    record_info("enclaves", $enclaves);
    $enclaves = decode_json($enclaves);
    die "no enclaves are running" unless (@$enclaves > 0);
    die "more than one enclave is running" if (@$enclaves > 1);
    my $enclave = $enclaves->[0];
    my $id = $enclave->{EnclaveID};
    my $log = $instance->ssh_script_output("sudo nitro-cli console --disconnect-timeout 10 --enclave-id $id");
    die "enclave console is not validating" unless ($log =~ "Hello Enclave");
    $instance->ssh_assert_script_run("sudo nitro-cli terminate-enclave --enclave-id $id");
}

sub post_fail_hook {
    my ($self) = @_;
    my $instance = publiccloud::instances::get_instance();

    # Collect the dmesg and allocator logs
    $instance->ssh_script_run("sudo dmesg > dmesg.log");
    $instance->ssh_script_run("sudo journalctl -eu nitro-enclaves-allocator.service > nitro-enclaves-allocator-service.log");
    $instance->scp("remote:{nitro-enclaves-allocator-service.log,dmesg.log} .");
    upload_logs("nitro-enclaves-allocator-service.log", failok => 1);
    upload_logs("dmesg.log", failok => 1);
    $self->SUPER::post_fail_hook;
}

1;
