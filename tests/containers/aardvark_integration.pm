# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: aardvark-dns
# Summary: Upstream aardvark-dns integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils qw(script_retry);
use containers::common;
use containers::bats qw(install_bats enable_modules);
use version_utils qw(is_sle is_tumbleweed);

my $test_dir = "/var/tmp";
my $aardvark = "";
my $aardvark_version = "";

sub run_tests {
    my %params = @_;
    my ($skip_tests) = ($params{skip_tests});

    return if ($skip_tests eq "all");

    my $log_file = "aardvark.tap";

    assert_script_run "cp -r test.orig test";
    my @skip_tests = split(/\s+/, get_var('AARDVARK_BATS_SKIP', '') . " " . $skip_tests);
    script_run "rm test/$_.bats" foreach (@skip_tests);

    assert_script_run "echo $log_file .. > $log_file";
    script_run "AARDVARK=$aardvark bats --tap test | tee -a $log_file", 1200;
    parse_extra_log(TAP => $log_file);
    assert_script_run "rm -rf test";
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    install_bats;
    enable_modules if is_sle;

    # Install tests dependencies
    my @pkgs = qw(aardvark-dns firewalld iproute2 iptables jq netavark slirp4netns);
    if (is_tumbleweed) {
        push @pkgs, qw(dbus-1-daemon ncat);
    } elsif (is_sle) {
        push @pkgs, qw(dbus-1);
    }
    install_packages(@pkgs);

    my $aardvark = script_output "rpm -ql aardvark-dns | grep podman/aardvark-dns";
    record_info("aardvark version", script_output("$aardvark --version"));

    my $test_dir = "/var/tmp";
    assert_script_run "cd $test_dir";

    # Download aardvark sources
    $aardvark_version = script_output "$aardvark --version | awk '{ print \$2 }'";
    script_retry("curl -sL https://github.com/containers/aardvark-dns/archive/refs/tags/v$aardvark_version.tar.gz | tar -zxf -", retry => 5, delay => 60, timeout => 300);
    assert_script_run "cd $test_dir/aardvark-dns-$aardvark_version/";
    assert_script_run "cp -r test test.orig";

    run_tests(skip_tests => get_var('AARDVARK_BATS_SKIP', ''));
}

sub cleanup() {
    assert_script_run "cd ~";
    script_run("rm -rf $test_dir/aardvark-$aardvark_version/");
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
