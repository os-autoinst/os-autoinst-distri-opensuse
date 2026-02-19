# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Packages: docker
# Summary: Upstream docker-buildx tests
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
    my @pkgs = qw(distribution-registry docker docker-buildx go1.25);
    push @pkgs, qw(buildkit docker-compose) unless is_sle("<16");
    $self->setup_pkgs(@pkgs);
    install_gotestsum;

    configure_docker(selinux => 1, tls => 1);

    # The tests expect the plugins to be in PATH without the "docker-" prefix
    my $docker_buildx = "/usr/lib/docker/cli-plugins/docker-buildx";
    my $docker_compose = "/usr/lib/docker/cli-plugins/docker-compose";
    run_command "cp $docker_buildx /usr/local/bin/buildx";
    run_command "cp $docker_compose /usr/local/bin/compose";

    $version = script_output qq($docker_buildx version | awk '{ print \$2 }');
    $version = "v$version" if ($version !~ /^v/);
    record_info "docker-buildx version", $version;

    patch_sources "buildx", $version, "tests";
}

sub run {
    my $self = shift;
    select_serial_terminal;
    $self->setup;
    select_serial_terminal;

    my %env = (
        TZ => "UTC",
    );
    my $env = join " ", map { "$_=\"$env{$_}\"" } sort keys %env;

    my @xfails = ();
    push @xfails, (
        # These tests fail on aarch64
        "github.com/docker/buildx/tests::TestIntegration",
        "github.com/docker/buildx/tests::TestIntegration/TestBuildAnnotations/worker=remote",
    ) if (is_aarch64);
    push @xfails, (
        "github.com/docker/buildx/tests::TestIntegration",
        "github.com/docker/buildx/tests::TestIntegration/TestComposeBuildCheck/worker=remote",
        "github.com/docker/buildx/tests::TestIntegration/TestComposeBuildRegistry/worker=remote",
    ) if (is_sle);

    my $rc = run_command "$env gotestsum --junitfile buildx.xml --format standard-verbose --packages=./tests", no_assert => 1, timeout => 1200;
    patch_junit "docker-buildx", $version, "buildx.xml", @xfails;
    parse_extra_log(XUnit => "buildx.xml", timeout => 180);
    die "Test failed" if $rc;
}

sub cleanup {
    script_run 'rm -vf /usr/local/bin/{buildx,compose}';
    cleanup_docker;
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
