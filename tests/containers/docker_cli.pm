# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Packages: docker
# Summary: Upstream docker-cli e2e tests
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
    my @pkgs = qw(docker docker-buildx go1.25);
    push @pkgs, qw(docker-compose) unless is_sle("<16");
    $self->setup_pkgs(@pkgs);
    install_gotestsum;

    configure_docker(selinux => 1, tls => 0);

    run_command "docker run -d --name registry -p 5000:5000 registry.opensuse.org/opensuse/registry:2";

    # Some tests have /usr/local/go/bin/go hard-coded
    run_command 'ln -s /usr /usr/local/go';

    run_command "echo 127.0.0.1 registry >> /etc/hosts";

    $version = script_output "docker version --format '{{.Client.Version}}'";
    $version =~ s/-ce$//;
    $version = "v$version";
    record_info "docker version", $version;

    patch_sources "cli", $version, "e2e";

    run_command "cp vendor.mod go.mod";
    run_command "cp vendor.sum go.sum";

    # We don't test Docker Content Trust
    run_command "rm -rf e2e/trust";
    run_command "TARGET=build/ ./scripts/build/plugins e2e/cli-plugins/plugins/*";

    # Fetch needed images
    run_command "./scripts/test/e2e/load-image";
    # Init Docker Swarm
    my $ip_addr = script_output("ip -j route get 8.8.8.8 | jq -Mr '.[0].prefsrc'");
    run_command "docker swarm init --advertise-addr $ip_addr";
    # Init Docker Compose
    run_command "COMPOSE_PROJECT_NAME=clie2e COMPOSE_FILE=./e2e/compose-env.yaml docker compose up --build -d registry";
}

sub run {
    my $self = shift;
    select_serial_terminal;
    $self->setup;
    select_serial_terminal;

    my $arch = go_arch(get_var("ARCH"));

    my %env = (
        DOCKER_CONTENT_TRUST => "",
        TEST_DOCKER_HOST => "localhost:2375",
        DOCKER_CLI_E2E_PLUGINS_EXTRA_DIRS => "/var/tmp/cli/build/plugins-linux-$arch",
    );
    my $env = join " ", map { "$_=\"$env{$_}\"" } sort keys %env;

    run_command "$env gotestsum --junitfile cli.xml ./e2e/... -- |& tee cli.txt", timeout => 3000;

    my @xfails = (
        # NOTE: This list can be removed when we upgrade to Docker v29
        # Expected failures from Docker Content Trust (notary is not supported)
        "github.com/docker/cli/e2e/container::TestCreateWithContentTrust",
        "github.com/docker/cli/e2e/container::TestRunWithContentTrust",
        "github.com/docker/cli/e2e/container::TestTrustedCreateFromBadTrustServer",
        "github.com/docker/cli/e2e/container::TestTrustedCreateFromUnreachableTrustServer",
        "github.com/docker/cli/e2e/container::TestTrustedRunFromBadTrustServer",
        "github.com/docker/cli/e2e/container::TestUntrustedRun",
        "github.com/docker/cli/e2e/global::TestTLSVerify",
        "github.com/docker/cli/e2e/image::TestPullWithContentTrust",
        "github.com/docker/cli/e2e/image::TestPullWithContentTrustUsesCacheWhenNotaryUnavailable",
        "github.com/docker/cli/e2e/image::TestPushWithContentTrust",
        "github.com/docker/cli/e2e/image::TestPushWithContentTrustExistingTag",
        "github.com/docker/cli/e2e/image::TestPushWithContentTrustReleasesDelegationOnly",
        "github.com/docker/cli/e2e/image::TestPushWithContentTrustSignsAllFirstLevelRolesWeHaveKeysFor",
        "github.com/docker/cli/e2e/image::TestPushWithContentTrustSignsForRolesWithKeysAndValidPaths",
        "github.com/docker/cli/e2e/image::TestTrustedBuild",
        "github.com/docker/cli/e2e/image::TestTrustedBuildUntrustedImage",
        "github.com/docker/cli/e2e/plugin::TestInstallWithContentTrustUntrusted",
    );
    # These tests fail on SLES 15-SP7 due to SUSE patch
    push @xfails, (
        "github.com/docker/cli/e2e/image::TestBuildFromContextDirectoryWithTag",
    ) if (is_sle("<16"));

    patch_junit "docker", $version, "cli.xml", @xfails;
    parse_extra_log(XUnit => "cli.xml");
    upload_logs("cli.txt");
}

sub cleanup {
    script_run "docker rm -vf registry";
    script_run "COMPOSE_PROJECT_NAME=clie2e COMPOSE_FILE=./e2e/compose-env.yaml docker compose down -v --rmi all";
    script_run "docker swarm leave -f";
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
