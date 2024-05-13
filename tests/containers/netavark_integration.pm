# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: netavark aardvark-dns
# Summary: Upstream netavark integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils qw(script_retry);
use containers::common;
use containers::bats qw(install_bats enable_modules);
use version_utils qw(is_sle);

my $test_dir = "/var/tmp";
my $netavark_version = "";

sub run_tests {
    my %params = @_;
    my ($skip_tests) = ($params{skip_tests});

    return if ($skip_tests eq "all");

    my $log_file = "netavark.tap";

    assert_script_run "cp -r test.orig test";
    my @skip_tests = split(/\s+/, get_var('NETAVARK_BATS_SKIP', '') . " " . $skip_tests);
    script_run "rm test/$_.bats" foreach (@skip_tests);

    assert_script_run "echo $log_file .. > $log_file";
    script_run "PATH=/usr/local/bin:\$PATH NETAVARK=/usr/libexec/podman/netavark bats --tap test | tee -a $log_file", 1200;
    parse_extra_log(TAP => $log_file);
    assert_script_run "rm -rf test";
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    install_bats;
    enable_modules if is_sle;

    # Install tests dependencies
    my @pkgs = qw(aardvark-dns dbus-1-daemon firewalld iproute2 iptables jq ncat netavark);
    install_packages(@pkgs);

    # netavark needs nmap's ncat instead of openbsd-netcat which we override via PATH above
    assert_script_run "cp /usr/bin/ncat /usr/local/bin/nc";

    record_info("netavark version", script_output("/usr/libexec/podman/netavark --version"));

    my $test_dir = "/var/tmp";
    assert_script_run "cd $test_dir";

    # Download netavark sources
    $netavark_version = script_output "/usr/libexec/podman/netavark --version | awk '{ print \$2 }'";
    script_retry("curl -sL https://github.com/containers/netavark/archive/refs/tags/v$netavark_version.tar.gz | tar -zxf -", retry => 5, delay => 60, timeout => 300);
    assert_script_run "cd $test_dir/netavark-$netavark_version/";
    assert_script_run "cp -r test test.orig";

    run_tests(skip_tests => get_var('NETAVARK_BATS_SKIP', ''));
}

sub cleanup() {
    assert_script_run "cd ~";
    script_run("rm -rf $test_dir/netavark-$netavark_version/");
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
