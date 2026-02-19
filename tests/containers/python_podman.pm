# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Packages: python3-podman
# Summary: Test podman-py
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest', -signatures;
use testapi;
use serial_terminal qw(select_serial_terminal);
use version_utils;
use utils;
use Utils::Architectures qw(is_x86_64);
use containers::bats;

my $version;

sub setup {
    my $self = shift;

    my @pkgs = qq(jq make podman python3 python3-fixtures python3-podman python3-pytest python3-requests-mock);
    $self->setup_pkgs(@pkgs);

    if (get_var("ROOTLESS")) {
        switch_to_user;
        run_command "systemctl --user enable --now podman.socket";
    }

    $version = script_output "python3 -c 'import podman; print(podman.__version__)'";
    $version = "v$version";
    record_info("podman-py version", $version);

    patch_sources "podman-py", $version, "podman/tests";
}

sub test ($target) {
    # Used by pytest to ignore whole files
    my @ignore = ();
    my $ignore = join " ", map { "--ignore=$_" } @ignore;

    # Used by pytest to ignore individual tests
    my @deselect = ();
    push @deselect, (
        # This test depends on an image available only for x86_64
        "podman/tests/integration/test_manifests.py::ManifestsIntegrationTest::test_manifest_crud",
    ) unless is_x86_64;
    my $deselect = join " ", map { "--deselect=$_" } @deselect;

    my @xfails = ();
    push @xfails, (
        "podman.tests.integration.test_container_create.ContainersIntegrationTest::test_container_devices",
    ) if (get_var("ROOTLESS"));

    my %env = ();
    my $env = join " ", map { "$_=$env{$_}" } sort keys %env;
    my $pytest_args = "-vv --capture=tee-sys -o junit_logging=all --junit-xml $target.xml $ignore $deselect";

    run_command "$env pytest $pytest_args podman/tests/$target", no_assert => 1, timeout => 3600;
    patch_junit "podman-py", $version, "$target.xml", @xfails;
    parse_extra_log(XUnit => "$target.xml", timeout => 180);
}

sub run {
    my $self = shift;
    select_serial_terminal;
    $self->setup;

    my $default_targets = "unit integration";
    my @targets = split(/\s+/, get_var('RUN_TESTS', $default_targets));
    foreach my $target (@targets) {
        test $target;
    }
}

sub cleanup {
    cleanup_podman;
    my $user = get_var("ROOTLESS") ? "--user" : "";
    script_run "systemctl $user stop podman.socket";
}

sub post_fail_hook {
    bats_post_hook;
    cleanup;
}

sub post_run_hook {
    bats_post_hook;
    cleanup;
}

1;
