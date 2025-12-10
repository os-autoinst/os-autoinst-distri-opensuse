# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Packages: docker-compose
# Summary: Upstream docker-compose tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest', -signatures;
use testapi;
use serial_terminal qw(select_serial_terminal);
use version_utils;
use utils;
use Utils::Architectures;
use containers::bats;

my $docker_compose = "/usr/lib/docker/cli-plugins/docker-compose";
my $version;

sub setup {
    my $self = shift;
    my @pkgs = qw(docker docker-buildx docker-compose go1.24 make);
    $self->setup_pkgs(@pkgs);

    # docker-compose needs to be patched upstream to support SELinux
    configure_docker(selinux => 0, tls => 1);

    # Some tests need this file
    run_command "mkdir /root/.docker || true";
    run_command "touch /root/.docker/config.json";

    $version = script_output "$docker_compose version | awk '{ print \$4 }'";
    # Temporary fix for v5.0.0
    $version = ($version =~ /dev/) ? "v5.0.0" : "v$version";
    record_info "docker-compose version", $version;

    patch_sources "compose", $version, "pkg/e2e";
}


sub test ($target) {
    my %env = (
        COMPOSE_E2E_BIN_PATH => $docker_compose,
        # This test fails on v2.39.2 at least
        EXCLUDE_E2E_TESTS => 'TestWatchMultiServices|TestBuildTLS',
    );
    # Fails on non-x86_64 with: "exec /transform: exec format error"
    $env{EXCLUDE_E2E_TESTS} .= "|TestConvertAndTransformList" unless is_x86_64;
    my $env = join " ", map { "$_=\"$env{$_}\"" } sort keys %env;

    my @xfails = ();

    run_command "$env make $target |& tee $target.txt || true", timeout => 3600;

    assert_script_run "mv /tmp/report/report.xml $target.xml";
    patch_junit "docker-compose", $version, "$target.xml", @xfails;
    parse_extra_log(XUnit => "$target.xml");
    upload_logs("$target.txt");
}

sub run {
    my ($self, $args) = @_;

    select_serial_terminal;
    $self->setup;

    select_serial_terminal;
    assert_script_run "cd /var/tmp/compose";
    run_command 'PATH=$PATH:/var/tmp/compose/bin/build';

    my @targets = split(/\s+/, get_var("RUN_TESTS", "e2e-compose e2e-compose-standalone"));
    test $_ foreach (@targets);
}

sub cleanup {
    cleanup_docker;
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
