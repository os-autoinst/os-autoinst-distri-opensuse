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

use Mojo::Base 'consoletest';
use v5.20;
use feature qw(signatures);
no warnings qw(experimental::signatures);
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils qw(install_package uninstall_package);
use python_version_utils;
use version_utils 'is_sle';
use registration;

sub test_setup {
    select_serial_terminal;
    # Import python scripts
    assert_script_run("curl -O " . data_url("python/websockets/client-test.py"));
    assert_script_run("curl -O " . data_url("python/websockets/server.py"));
}

sub run_test ($python_package) {
    return unless script_run("zypper search $python_package-websocket-client") == 0;
    record_info("Testing for", "$python_package is tested now");
    install_package("$python_package $python_package-websocket-client $python_package-tornado", trup_continue => 1, trup_reboot => 1);

    # Start websocket server in background AFTER reboot
    my $python_interpreter = get_python3_binary($python_package);
    my $server_pid = background_script_run "$python_interpreter server.py";
    # Wait up to 30 seconds for port 8000 to be active
    assert_script_run("timeout 30 bash -c 'until printf \"\" 2>>/dev/null >>/dev/tcp/127.0.0.1/8000; do sleep 1; done'");

    record_info("running python version", script_output("$python_interpreter --version"));
    # Execute python script. The script itself ensure output is the one expected
    assert_script_run("$python_interpreter client-test.py");

    # Stop websocket server for this specific version
    assert_script_run "kill $server_pid";

    # clean up for the next run
    uninstall_package("$python_package $python_package-websocket-client", trup_continue => 1, trup_reboot => 1);
}

sub run {
    my $self = shift;
    add_suseconnect_product(get_addon_fullname('python3')) if is_sle('<16.0');
    my $server_pid = test_setup();
    my @python3_versions = get_available_python_versions();
    unshift @python3_versions, "python3";    # append the system default one
    run_test($_) foreach @python3_versions;
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
