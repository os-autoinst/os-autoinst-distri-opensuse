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
use registration qw(add_suseconnect_product get_addon_fullname);
use containers::bats;

my $version;

sub setup {
    my $self = shift;

    add_suseconnect_product(get_addon_fullname('python3')) if (is_sle('>=15-SP4') && is_sle("<16"));
    my $python3 = is_sle("<16") ? "python311" : "python3";
    my @pkgs = qq(jq make podman $python3 $python3-fixtures $python3-podman $python3-pytest $python3-requests-mock);
    $self->setup_pkgs(@pkgs);

    systemctl "enable --now podman.socket";
    # Transform "python311" into "python3.11" and leave "python3" as is
    $python3 =~ s/^python3(\d{2})$/python3.$1/;
    $version = script_output "$python3 -c 'import podman; print(podman.__version__)'";
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
        "podman/tests/integration/test_manifests.py::ManifestsIntegrationTest::test_manifest_crud"
    ) unless is_x86_64;
    my $deselect = join " ", map { "--deselect=$_" } @deselect;

    my %env = ();
    my $env = join " ", map { "$_=$env{$_}" } sort keys %env;
    my $pytest_args = "-vv --capture=tee-sys -o junit_logging=all --junit-xml $target.xml $ignore $deselect";

    run_command "$env pytest $pytest_args podman/tests/$target &> $target.txt || true", timeout => 3600;

    patch_junit "podman-py", $version, "$target.xml";
    parse_extra_log(XUnit => "$target.xml");
    upload_logs("$target.txt");
}

sub run {
    my $self = shift;

    select_serial_terminal;
    $self->setup;

    select_serial_terminal;
    test $_ foreach (qw(unit integration));
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
