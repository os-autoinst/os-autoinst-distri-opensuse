# SUSE's openQA tests
#
# Copyright @ SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Operates as the client of the dolly server and checks final results
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base qw(hpcbase btrfs_test), -signatures;
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use utils;

our $test_dir = "/mnt/test";
our $test_dev;

sub run ($self) {
    select_serial_terminal();
    $self->set_playground_disk();    # sets PLAYGROUNDDISK variable
    $test_dev = get_required_var('PLAYGROUNDDISK');
    record_info 'test_dev', "$test_dev";

    zypper_call("in dolly");
    barrier_wait("DOLLY_INSTALLATION_FINISHED");
    assert_script_run("mkfs.ext4 -v $test_dev");
    barrier_wait("DOLLY_SERVER_READY");
    assert_script_run("dolly -v", timeout => 1600);    # timeout should be in sync with master_node
    barrier_wait("DOLLY_DONE");
    assert_script_run("mkdir -p $test_dir");
    assert_script_run("mount $test_dev $test_dir");
    script_run("ls -la $test_dir");
    my @data_files = split(/\n/, script_output("ls -1 ${test_dir}/data*"));
    foreach my $file (@data_files) {
        my $expected_hash = script_output("sha256sum $file");
        record_info "hash $file", $expected_hash;
        assert_script_run(qq@test "$expected_hash" = "\$(grep '$expected_hash' ${test_dir}/hashes.sha256)"@);
        record_info "$file results", 'test pass successfully';
    }
}

sub test_flags ($self) {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook ($self) {
    $self->destroy_test_barriers();
}

1;
