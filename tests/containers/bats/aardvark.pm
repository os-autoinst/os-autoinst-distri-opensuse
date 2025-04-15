# SUSE's openQA tests
#
# Copyright 2024,2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: aardvark-dns
# Summary: Upstream aardvark-dns integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils qw(script_retry);
use containers::common;
use containers::bats;
use version_utils qw(is_sle is_tumbleweed);

my $test_dir = "/var/tmp/aardvark-tests";
my $aardvark = "";

sub run_tests {
    my $tmp_dir = script_output "mktemp -d -p /var/tmp test.XXXXXX";
    my $netavark = script_output "rpm -ql netavark | grep podman/netavark";

    my %_env = (
        AARDVARK => $aardvark,
        NETAVARK => $netavark,
        BATS_TMPDIR => $tmp_dir,
    );
    my $env = join " ", map { "$_=$_env{$_}" } sort keys %_env;

    my $log_file = "aardvark.tap";
    assert_script_run "echo $log_file .. > $log_file";

    my @tests;
    foreach my $test (split(/\s+/, get_var("BATS_TESTS", ""))) {
        $test .= ".bats" unless $test =~ /\.bats$/;
        push @tests, "test/$test";
    }
    my $tests = @tests ? join(" ", @tests) : "test";

    my $ret = script_run "env $env bats --tap $tests | tee -a $log_file", 2000;

    unless (@tests) {
        my @skip_tests = split(/\s+/, get_var('BATS_SKIP', ''));
        patch_logfile($log_file, @skip_tests);
    }

    parse_extra_log(TAP => $log_file);
    script_run "rm -rf $tmp_dir";

    return ($ret);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # Install tests dependencies
    my @pkgs = qw(aardvark-dns firewalld iproute2 iptables jq netavark podman);
    if (is_tumbleweed || is_sle('>=16.0')) {
        push @pkgs, qw(dbus-1-daemon);
    } elsif (is_sle) {
        push @pkgs, qw(dbus-1);
    }

    $self->bats_setup(@pkgs);

    install_ncat;

    $aardvark = script_output "rpm -ql aardvark-dns | grep podman/aardvark-dns";
    record_info("aardvark-dns version", script_output("$aardvark --version"));
    record_info("aardvark-dns package version", script_output("rpm -q aardvark-dns"));

    # Download aardvark sources
    my $aardvark_version = script_output "$aardvark --version | awk '{ print \$2 }'";
    my $url = get_var("BATS_URL", "https://github.com/containers/aardvark-dns/archive/refs/tags/v$aardvark_version.tar.gz");
    assert_script_run "mkdir -p $test_dir";
    assert_script_run "cd $test_dir";
    script_retry("curl -sL $url | tar -zxf - --strip-components 1", retry => 5, delay => 60, timeout => 300);

    my $errors = run_tests;
    die "ardvark-dns tests failed" if ($errors);
}

sub post_fail_hook {
    bats_post_hook $test_dir;
}

sub post_run_hook {
    bats_post_hook $test_dir;
}

1;
