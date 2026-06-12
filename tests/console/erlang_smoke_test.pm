# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
#
# Summary: Smoke test for erlang
# Maintainer: QE-Core <qe-core@suse.de>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils;
use registration qw(runtime_registration add_suseconnect_product);
use package_utils 'install_package';


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
    record_info("Installing packages");
    install_package("$pkg_list", trup_reboot => 1);
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
        my $msg = "Rebar3 :App directory not created. Output: $rebar_result";
        record_soft_failure "bsc#1232721 - $msg";
    }
}

sub run {
    select_serial_terminal;

    # Step 1: Install Erlang and Elixir packages
    runtime_registration() if $requires_scc_registration;
    install_pkgs();

    # Step 2: Verify installation
    record_info('Verify', 'Checking if Erlang and Elixir are installed');
    assert_script_run('erl -eval "erlang:display(erlang:system_info(otp_release)), halt()." -noshell');
    assert_script_run('elixir -v');

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
