# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: python3-websocket-client tests
# - ensure python3 module is enabled in the system
# - install python-websocket-client package
# - use library to connect and transfer some data to a test server
# - Compare the result vs expected
#
# Maintainer: QE-Core <qe-core@suse.de>

use base 'consoletest';
use warnings;
use strict;
use v5.20;
use feature qw(signatures);
no warnings qw(experimental::signatures);
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use python_version_utils;
use version_utils 'is_sle';
use registration;

sub test_setup {
    select_serial_terminal;
    # Import python scripts
    assert_script_run("curl -O " . data_url("python/websockets/client-test.py"));
    assert_script_run("curl -O " . data_url("python/websockets/server.py"));
    # install server dependencies
    zypper_call("install python3-tornado");
    # start websocket server in background
    return background_script_run 'python3 server.py';
}

sub run_test ($python_package) {
    return unless script_run("zypper search $python_package-websocket-client") == 0;
    record_info("Testing for $python_package");
    zypper_call("install $python_package $python_package-websocket-client");
    my $python_interpreter = get_python3_binary($python_package);
    record_info("running python version", script_output("$python_interpreter --version"));
    # Execute python script. The script itself ensure output is the one expected
    assert_script_run("$python_interpreter client-test.py");
    # clean up for the next run
    zypper_call("rm $python_package $python_package-websocket-client");
}

sub run {
    my $self = shift;
    add_suseconnect_product(get_addon_fullname('python3')) if is_sle();
    my $server_pid = test_setup();
    my @python3_versions = get_available_python_versions();
    unshift @python3_versions, "python3";    # append the system default one
    run_test($_) foreach @python3_versions;
    # stop websocket server
    assert_script_run "kill $server_pid";
}

sub post_fail_hook {
    my $self = shift;
    cleanup();
    $self->SUPER::post_fail_hook;
}

sub cleanup {
    remove_installed_pythons();
    script_run("rm -f client-test.py server.py");
}

1;
