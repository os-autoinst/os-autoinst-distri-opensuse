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
    my @pkgs = qw(buildkit distribution-registry docker docker-buildx docker-compose go1.24);
    $self->setup_pkgs(@pkgs);
    install_gotestsum;

    # The tests assume a vanilla configuration
    run_command "mv -f /etc/docker/daemon.json{,.bak}";
    run_command "mv -f /etc/sysconfig/docker{,.bak}";
    # The tests use both network & Unix socket
    run_command q(echo 'DOCKER_OPTS="-H 0.0.0.0:2375 -H unix:///var/run/docker.sock --experimental"' > /etc/sysconfig/docker);
    run_command "systemctl enable docker";
    run_command "systemctl restart docker";
    record_info "docker info", script_output("docker info");

    # The tests expect the plugins to be in PATH without the "docker-" prefix
    run_command 'cp /usr/lib/docker/cli-plugins/docker-buildx /usr/local/bin/buildx';
    run_command 'cp /usr/lib/docker/cli-plugins/docker-compose /usr/local/bin/compose';

    $version = script_output q(/usr/lib/docker/cli-plugins/docker-buildx version | awk '{ print $3 }');
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

    my @xfails = (
        # These tests fail because they need multiple workers
        "github.com/docker/buildx/tests::TestIntegration/TestVersion/worker=remote",
        "github.com/docker/buildx/tests::TestIntegration",
    );
    push @xfails, (
        # These tests fail on aarch64
        "github.com/docker/buildx/tests::TestIntegration/TestBuildAnnotations/worker=remote",
    ) if (is_aarch64);

    run_command "$env gotestsum --junitfile buildx.xml --format standard-verbose --packages=./tests |& tee buildx.txt", timeout => 1200;

    patch_junit "docker-buildx", $version, "buildx.xml", @xfails;
    parse_extra_log(XUnit => "buildx.xml");
    upload_logs("buildx.txt");
}

sub cleanup {
    script_run "mv -f /etc/docker/daemon.json{.bak,}";
    script_run "mv -f /etc/sysconfig/docker{.bak,}";
    script_run 'docker rm -vf $(docker ps -aq)';
    script_run "docker system prune -a -f --volumes";
    systemctl "restart docker";
    script_run 'rm -vf /usr/local/bin/{buildx,compose}';
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
