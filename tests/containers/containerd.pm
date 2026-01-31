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
    my @pkgs = qw(containerd containerd-ctr go1.25 make);
    $self->setup_pkgs(@pkgs);
    install_gotestsum;

    run_command "systemctl enable --now containerd";
    record_info "containerd status", script_output("systemctl status containerd");

    $version = script_output q(containerd --version | awk '{ print $3 }');
    record_info "containerd version", $version;

    patch_sources "containerd", $version, "integration";

    run_command "make bin/containerd-shim-runc-fp-v1 bin/cni-bridge-fp bin/runc-fp";
    run_command 'export PATH=$PATH:$PWD/bin';
    run_command "cd integration/client";
    run_command "go mod download";
}

sub run {
    my $self = shift;
    select_serial_terminal;
    $self->setup;
    select_serial_terminal;

    my %env = ();
    my $env = join " ", map { "$_=\"$env{$_}\"" } sort keys %env;

    run_command "$env gotestsum --junitfile containerd.xml --format standard-verbose ./... -- -test.root |& tee containerd.txt", timeout => 600;

    my @xfails = ();

    patch_junit "containerd", $version, "containerd.xml", @xfails;
    parse_extra_log(XUnit => "containerd.xml");
    upload_logs("containerd.txt");
}

sub post_fail_hook {
    my ($self) = @_;
    bats_post_hook;
}

sub post_run_hook {
    my ($self) = @_;
    bats_post_hook;
}

1;
