# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Packages: containerd
# Summary: Upstream containerd tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest', -signatures;
use testapi;
use serial_terminal qw(select_serial_terminal);
use version_utils;
use utils;
use Utils::Architectures;
use containers::bats;

my $version;

sub setup {
    my $self = shift;
    my @pkgs = qw(containerd containerd-ctr go1.25 make xfsprogs);
    $self->setup_pkgs(@pkgs);
    install_gotestsum;

    run_command "systemctl enable --now containerd";
    record_info "containerd status", script_output("systemctl status containerd");

    $version = script_output q(containerd --version | awk '{ print $3 }');
    record_info "containerd version", $version;

    patch_sources "containerd", $version, "integration";

    run_command "make bin/runc-fp";
    run_command "cp bin/runc-fp /usr/local/bin";
    run_command "cd integration/client";
    run_command "go mod download";
}

sub run {
    my $self = shift;
    select_serial_terminal;
    $self->setup;
    select_serial_terminal;

    run_command "gotestsum --junitfile containerd.xml --format standard-verbose ./... -- -v -test.root |& tee containerd.txt", timeout => 600;

    my @xfails = ();

    patch_junit "containerd", $version, "containerd.xml", @xfails;

    parse_extra_log(XUnit => "containerd.xml", timeout => 180);
    upload_logs("containerd.txt");
}

sub cleanup {
    script_run "rm -f /usr/local/bin/runc-fp";
}

sub post_fail_hook {
    my ($self) = @_;
    cleanup;
    bats_post_hook;
}

sub post_run_hook {
    my ($self) = @_;
    cleanup;
    bats_post_hook;
}

1;
