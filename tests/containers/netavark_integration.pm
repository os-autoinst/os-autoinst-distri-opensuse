# SUSE's openQA tests
#
# Copyright 2024,2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: netavark
# Summary: Upstream netavark integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils qw(script_retry);
use containers::common;
use containers::bats;
use version_utils qw(is_sle is_tumbleweed);

my $test_dir = "/var/tmp/netavark-tests";
my $netavark;
my $firewalld_backend;

sub run_tests {
    my $tmp_dir = script_output "mktemp -d -p /var/tmp test.XXXXXX";

    my %_env = (
        NETAVARK => $netavark,
        BATS_TMPDIR => $tmp_dir,
        PATH => '/usr/local/bin:$PATH:/usr/sbin:/sbin',
    );
    my $env = join " ", map { "$_=$_env{$_}" } sort keys %_env;

    my $log_file = "netavark.tap";
    assert_script_run "echo $log_file .. > $log_file";

    my @tests;
    foreach my $test (split(/\s+/, get_var("NETAVARK_BATS_TESTS", ""))) {
        $test .= ".bats" unless $test =~ /\.bats$/;
        push @tests, "test/$test";
    }
    my $tests = @tests ? join(" ", @tests) : "test";

    my $ret = script_run "env $env bats --tap $tests | tee -a $log_file", 1200;

    unless (@tests) {
        my @skip_tests = split(/\s+/, get_var('NETAVARK_BATS_SKIP', ''));
        # Unconditionally ignore these flaky subtests
        my @must_skip = ();
        push @must_skip, "100-bridge-iptables" if ($firewalld_backend ne "iptables");
        push @skip_tests, @must_skip;
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
    my @pkgs = qw(aardvark-dns cargo firewalld iproute2 iptables jq make protobuf-devel netavark);
    if (is_tumbleweed || is_sle('>=16.0')) {
        push @pkgs, qw(dbus-1-daemon);
    } elsif (is_sle) {
        push @pkgs, qw(dbus-1);
    }
    install_packages(@pkgs);
    install_ncat;

    $self->bats_setup;

    $netavark = script_output "rpm -ql netavark | grep podman/netavark";
    record_info("netavark version", script_output("$netavark --version"));
    record_info("netavark package version", script_output("rpm -q netavark"));

    # Download netavark sources
    my $netavark_version = script_output "$netavark --version | awk '{ print \$2 }'";
    my $url = get_var("NETAVARK_BATS_URL", "https://github.com/containers/netavark/archive/refs/tags/v$netavark_version.tar.gz");
    assert_script_run "mkdir -p $test_dir";
    assert_script_run "cd $test_dir";
    script_retry("curl -sL $url | tar -zxf - --strip-components 1", retry => 5, delay => 60, timeout => 300);

    $firewalld_backend = script_output "awk -F= '\$1 == \"FirewallBackend\" { print \$2 }' < /etc/firewalld/firewalld.conf";
    record_info("Firewalld backend", $firewalld_backend);

    # Compile helpers & patch tests
    assert_script_run "make examples", timeout => 600;

    my $errors = run_tests;
    die "netavark tests failed" if ($errors);
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
