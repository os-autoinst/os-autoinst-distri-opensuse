# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: runc
# Summary: Upstream runc integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils qw(script_retry);
use containers::common;
use containers::bats qw(install_bats switch_to_user delegate_controllers);
use version_utils qw(is_tumbleweed is_sle_micro);

my $test_dir = "/var/tmp";
my $runc_version = "";

sub run_tests {
    my %params = @_;
    my ($rootless, $skip_tests) = ($params{rootless}, $params{skip_tests});

    my $log_file = "runc-" . ($rootless ? "user" : "root") . ".tap";

    assert_script_run "cp -r tests/integration.orig tests/integration";
    my @skip_tests = split(/\s+/, get_var('RUNC_BATS_SKIP', '') . " " . $skip_tests);
    script_run "rm tests/integration/$_.bats" foreach (@skip_tests);

    assert_script_run "echo $log_file .. > $log_file";
    script_run "RUNC=/usr/bin/runc RUNC_USE_SYSTEMD=1 bats --tap tests/integration | tee -a $log_file", 1200;
    parse_extra_log(TAP => $log_file);
    assert_script_run "rm -rf tests/integration";
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    install_bats;

    # Install tests dependencies
    my @pkgs = qw(git-core iptables jq runc);
    push @pkgs, "glibc-devel-static go libseccomp-devel make" unless is_sle_micro;
    push @pkgs, "criu" if is_tumbleweed;
    install_packages(@pkgs);

    delegate_controllers;

    switch_cgroup_version($self, 2);

    record_info("runc version", script_output("runc --version"));
    record_info("runc features", script_output("runc features"));

    switch_to_user;

    my $test_dir = "/var/tmp";
    assert_script_run "cd $test_dir";

    # Download runc sources
    $runc_version = script_output "runc --version  | awk '{ print \$3 }'";
    script_retry("curl -sL https://github.com/opencontainers/runc/archive/refs/tags/v$runc_version.tar.gz | tar -zxf -", retry => 5, delay => 60, timeout => 300);
    assert_script_run "cd $test_dir/runc-$runc_version/";
    assert_script_run "cp -r tests/integration tests/integration.orig";

    # Compile helpers used by the tests
    assert_script_run("make \$(ls contrib/cmd/)") unless is_sle_micro;

    run_tests(rootless => 1, skip_tests => get_var('RUNC_BATS_SKIP_USER', ''));

    select_serial_terminal;
    assert_script_run("cd $test_dir/runc-$runc_version/");

    run_tests(rootless => 0, skip_tests => get_var('RUNC_BATS_SKIP_ROOT', ''));
}

sub cleanup() {
    assert_script_run "cd ~";
    script_run("rm -rf $test_dir/runc-$runc_version/");
}

sub post_fail_hook {
    my ($self) = @_;
    cleanup();
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my ($self) = @_;
    cleanup();
    $self->SUPER::post_run_hook;
}

1;
