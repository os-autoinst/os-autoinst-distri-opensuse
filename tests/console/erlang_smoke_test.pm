# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
# Summary: Smoke test for erlang
# Maintainer: QE-Core <qe-core@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils;
use registration qw(runtime_registration add_suseconnect_product);
use transactional qw(trup_call process_reboot);
use utils 'zypper_call';

my $requires_scc_registration = is_sle_micro || is_sle;

sub install_pkgs {
    my @to_install = (
        "git",
        "erlang",
        "erlang-epmd",
        "erlang-getopt",
        "erlang-cf",
        "elixir",
        "erlang-providers",
        "erlang-erlware_commons",
        "elixir-hex",
        "erlang-rebar3"
    );

    my $pkg_list = join ' ', @to_install;

    if (is_transactional) {
        assert_script_run "rebootmgrctl set-strategy instantly";
        record_info("Installing packages", "Using transactional-update, requires reboot: $pkg_list");
        trup_call "reboot pkg install $pkg_list";
        process_reboot(expected_grub => 1);
        select_serial_terminal;
    } else {
        record_info("Installing packages", "Using zypper for installation: $pkg_list");
        zypper_call "in $pkg_list";
    }
}

sub run_smoke_test {
    record_info('Run Smoke Test', 'Running Erlang smoke test');
    assert_script_run('erl -noshell -pa ~/ -s erlang_smoke_test run -s init stop');
}

sub test_elixir_hex {
    record_info('Hex Test', 'Testing Elixir Hex availability');
    assert_script_run("mix local.hex --force");
    my $hex_result = script_output("mix hex.info", proceed_on_failure => 1);
    if ($hex_result =~ /Hex\:/) {
        record_info('Hex Test Passed', 'Hex is installed and accessible');
    } else {
        die 'Hex installation test failed';
    }
}

sub test_rebar3 {
    record_info('Rebar3 Test', 'Testing Rebar3 functionality');
    assert_script_run('git config --global user.name "Test"');
    assert_script_run('git config --global user.email "geekotest@suse.com"');
    assert_script_run("mkdir -p ~/.config/rebar3/");
    assert_script_run("cp -r /usr/lib64/erlang/lib/rebar3-*/priv/templates ~/.config/rebar3/");
    my $rebar_install = script_output('DIAGNOSTIC=1 rebar3 local install', proceed_on_failure => 1);
    record_info($rebar_install);
    my $rebar_result = script_output("DIAGNOSTIC=1 rebar3 new app sample_app", proceed_on_failure => 1);
    if (script_run("test -d sample_app") == 0) {
        record_info('Rebar3 Test Passed', 'Rebar3 created the app directory successfully');
        script_run("rm -rf sample_app");    # Clean up after the test
    } else {
        die "Rebar3 Test Failed. App directory not created. Output: $rebar_result";
    }
}

sub run {
    select_serial_terminal;

    # Step 1: Install Erlang and Elixir packages
    runtime_registration() if $requires_scc_registration;
    install_pkgs();

    # Step 2: Verify installation
    record_info('Verify', 'Checking if Erlang and Elixir are installed');
    assert_script_run('erl -eval "erlang:display(erlang:system_info(otp_release)), halt()." -noshell', timeout => 60);
    assert_script_run('elixir -v', timeout => 60);

    # Step 3: Download and compile smoke test
    assert_script_run("curl -v -o ~/erlang_smoke_test.erl " . data_url("console/erlang_smoke_test.erl"));
    assert_script_run("erlc -o ~/ ~/erlang_smoke_test.erl");


    # Step 4: Compile and run the smoke test script
    run_smoke_test();

    # Step 5: Smoke test HEX and ReBAR 3
    test_elixir_hex();
    test_rebar3();
}

1;
