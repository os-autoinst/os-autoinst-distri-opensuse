# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run test for post-quantum cyphers in go >=2.14
# Maintainer: QE Security <none@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';

sub run {
    select_serial_terminal;

    # Install Go
    record_info('Installing Go', 'Installing Go');
    zypper_call 'in go';
    my $go_version = script_output('go version');
    die "Unable to parse Go version: $go_version" if ($go_version !~ /go(\d+)\.(\d+)/);
    my ($major, $minor) = ($1, $2);
    if ($major < 1 || ($major == 1 && $minor < 24)) {
        record_soft_failure("Go >= 1.24.0 required (available $go_version); poo#182489");
        return;
    }
    record_info('Go Version', $go_version);

    # Prepare Test
    record_info('Preparing', 'Downloading test files');
    my $data_url = data_url('security/openqa_agnostic/goPostQuantum');
    my $test_dir = '~/go_post_quantum';
    assert_script_run "mkdir -p $test_dir";
    my @files = ('main.go', 'go.mod', 'runtest');
    for my $file (@files) {
        assert_script_run "curl -s -o $test_dir/$file $data_url/$file";
    }

    # Run Test
    record_info('Running', 'Executing the test binary');
    assert_script_run "cd $test_dir && chmod +x runtest";
    validate_script_output("./runtest", sub { m/Hello, post-quantum world!/ }, proceed_on_failure => 1);

    # Cleanup
    record_info('Cleaning', 'Cleaning');
    assert_script_run "cd .. && rm -rf $test_dir";
}

sub test_flags {
    return {always_rollback => 1};
}

1;
