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
use containers::bats qw(install_bats patch_logfile enable_modules);
use version_utils qw(is_sle is_tumbleweed);

my $test_dir = "/var/tmp";
my $netavark = "";
my $netavark_version = "";

sub run_tests {
    my $log_file = "netavark.tap";

    my @skip_tests = split(/\s+/, get_var('NETAVARK_BATS_SKIP', ''));

    assert_script_run "echo $log_file .. > $log_file";
    script_run "PATH=/usr/local/bin:\$PATH BATS_TMPDIR=/var/tmp NETAVARK=$netavark bats --tap test | tee -a $log_file", 1200;
    patch_logfile($log_file, @skip_tests);
    parse_extra_log(TAP => $log_file);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    install_bats;
    enable_modules if is_sle;

    # Install tests dependencies
    my @pkgs = qw(aardvark-dns firewalld netcat-openbsd iproute2 iptables jq netavark);
    if (is_tumbleweed) {
        push @pkgs, qw(dbus-1-daemon);
    } elsif (is_sle) {
        push @pkgs, qw(dbus-1);
    }
    install_packages(@pkgs);

    switch_cgroup_version($self, 2);

    $netavark = script_output "rpm -ql netavark | grep podman/netavark";
    record_info("netavark version", script_output("$netavark --version"));

    my $test_dir = "/var/tmp";
    assert_script_run "cd $test_dir";

    # Download netavark sources
    $netavark_version = script_output "$netavark --version | awk '{ print \$2 }'";
    script_retry("curl -sL https://github.com/containers/netavark/archive/refs/tags/v$netavark_version.tar.gz | tar -zxf -", retry => 5, delay => 60, timeout => 300);
    assert_script_run "cd $test_dir/netavark-$netavark_version/";

    run_tests;
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
