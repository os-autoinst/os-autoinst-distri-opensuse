# SUSE's openQA tests
#
# Copyright 2024-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: runc
# Summary: Upstream runc integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils qw(script_retry);
use containers::common;
use containers::bats;
use version_utils qw(is_sle is_tumbleweed);

my $test_dir = "/var/tmp/runc-tests";

sub run_tests {
    my %params = @_;
    my ($rootless, $skip_tests) = ($params{rootless}, $params{skip_tests});

    return if ($skip_tests eq "all");

    my $log_file = "runc-" . ($rootless ? "user" : "root") . ".tap";

    my $tmp_dir = script_output "mktemp -d -p /var/tmp test.XXXXXX";

    my %_env = (
        BATS_TMPDIR => $tmp_dir,
        RUNC_USE_SYSTEMD => "1",
        RUNC => "/usr/bin/runc",
        PATH => '/usr/local/bin:$PATH:/usr/sbin:/sbin',
    );
    my $env = join " ", map { "$_=$_env{$_}" } sort keys %_env;

    assert_script_run "echo $log_file .. > $log_file";

    my @tests;
    foreach my $test (split(/\s+/, get_var("RUNC_BATS_TESTS", ""))) {
        $test .= ".bats" unless $test =~ /\.bats$/;
        push @tests, "tests/integration/$test";
    }
    my $tests = @tests ? join(" ", @tests) : "tests/integration";

    my $ret = script_run "env $env bats --tap $tests | tee -a $log_file", 2000;

    unless (@tests) {
        my @skip_tests = split(/\s+/, get_var('RUNC_BATS_SKIP', '') . " " . $skip_tests);
        patch_logfile($log_file, @skip_tests);
    }

    parse_extra_log(TAP => $log_file);

    script_run "rm -rf $tmp_dir";

    return ($ret);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    install_bats;
    enable_modules if is_sle;

    # Install tests dependencies
    my @pkgs = qw(git-core glibc-devel-static go iptables jq libseccomp-devel make runc);
    push @pkgs, "criu" if is_tumbleweed;
    install_packages(@pkgs);

    $self->bats_setup;

    record_info("runc version", script_output("runc --version"));
    record_info("runc features", script_output("runc features"));
    record_info("runc package version", script_output("rpm -q runc"));

    switch_to_user;

    # Download runc sources
    my $runc_version = script_output "runc --version  | awk '{ print \$3 }'";
    my $url = get_var("RUNC_BATS_URL", "https://github.com/opencontainers/runc/archive/refs/tags/v$runc_version.tar.gz");
    assert_script_run "mkdir -p $test_dir";
    assert_script_run "cd $test_dir";
    script_retry("curl -sL $url | tar -zxf - --strip-components 1", retry => 5, delay => 60, timeout => 300);

    # Compile helpers used by the tests
    my $cmds = script_output "find contrib/cmd tests/cmd -mindepth 1 -maxdepth 1 -type d -printf '%f ' || true";
    script_run "make $cmds";

    my $errors = run_tests(rootless => 1, skip_tests => get_var('RUNC_BATS_SKIP_USER', ''));

    select_serial_terminal;
    assert_script_run("cd $test_dir");

    $errors += run_tests(rootless => 0, skip_tests => get_var('RUNC_BATS_SKIP_ROOT', ''));

    die "Tests failed" if ($errors);
}

sub post_fail_hook {
    my ($self) = @_;
    bats_post_hook $test_dir;
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my ($self) = @_;
    bats_post_hook $test_dir;
    $self->SUPER::post_run_hook;
}

1;
