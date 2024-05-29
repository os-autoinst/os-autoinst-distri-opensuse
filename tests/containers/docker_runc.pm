# SUSE's openQA tests
#
# Copyright 2017-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: runc docker-runc
# Summary: Test docker-runc and runc installation, and extended usage
#    Cover the following aspects of docker-runc and runc respectively:
#      * package can be installed
#      * create specification files
#      * run the container
#      * complete lifecycle (create, start, pause, resume, kill, delete)
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_leap is_sle get_os_release is_transactional);
use containers::common;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my ($running_version, $sp, $host_distri) = get_os_release;
    my $runc = "runc";    # runc executable

    # Runtime setup and installation
    record_info 'Test #1', 'Installation and test preparation';
    install_packages($runc);
    record_info("$runc", script_output("$runc -v"));
    # Create root filesystem for the test container. We need docker for this preparation step.
    assert_script_run('rm -rf rootfs && mkdir rootfs');
    my $image = "registry.opensuse.org/opensuse/busybox";
    assert_script_run('docker export $(docker create ' . $image . ') | tar -C rootfs -xvf -', fail_message => "Cannot export rootfs, see bsc#1152508");

    # create the OCI specification file and verify that the template has been created
    record_info 'Test #2', 'Test: OCI Specification';
    assert_script_run("$runc spec");
    assert_script_run('stat config.json', fail_message => "OCI specification file has not been created");
    script_run('cp config.json config_json.template');

    # Modify the configuration to run the container in background
    assert_script_run("sed -i -e '/\"terminal\":/ s/: .*/: false,/' config.json");
    assert_script_run("sed -i -e 's/\"sh\"/\"echo\", \"Kalimera\"/' config.json");

    # Run (create, start, and delete) the container after it exits
    record_info 'Test #3', 'Test: Use the run command';
    validate_script_output("$runc run test1", qr/Kalimera/);

    # Restore the default configuration
    assert_script_run('cp config_json.template config.json');

    assert_script_run("sed -i -e '/\"terminal\":/ s/: .*/: false,/' config.json");
    assert_script_run("sed -i -e 's/\"sh\"/\"sleep\", \"120\"/' config.json");

    # Container Lifecycle
    record_info 'Test #4', 'Test: Create a container';
    assert_script_run("$runc create test2");
    validate_script_output("$runc state test2", sub { $_ =~ m/.*"status":.*"created".*/m });
    record_info 'Test #5', 'Test: List containers';
    validate_script_output("$runc list", qr/test2/);
    record_info 'Test #6', 'Test: Start a container';
    assert_script_run("$runc start test2");
    validate_script_output("$runc state test2", qr/running/);
    record_info 'Test #7', 'Test: Pause a container';
    assert_script_run("$runc pause test2");
    validate_script_output("$runc state test2", qr/paused/);
    record_info 'Test #8', 'Test: Resume a container';
    assert_script_run("$runc resume test2");
    validate_script_output("$runc state test2", qr/running/);
    record_info 'Test #9', 'Test: Stop a container';
    assert_script_run("$runc kill test2 KILL");
    validate_script_output_retry("$runc state test2", qr/stopped/, retry => 3, delay => 30);
    record_info 'Test #10', 'Test: Delete a container';
    assert_script_run("$runc delete test2");
    assert_script_run("! $runc state test2");
}

sub cleanup {
    my ($self) = @_;
    # Remove temporary files
    script_run("rm -rf rootfs config.json config_json.template");
}

sub post_run_hook {
    my ($self) = @_;
    $self->cleanup();
}

sub post_fail_hook {
    my ($self) = @_;
    $self->cleanup();
}

1;
