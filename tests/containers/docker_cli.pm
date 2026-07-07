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
use version;
use utils;
use Utils::Architectures;
use containers::bats;

my $firewall_backend;
my $version;
my $port = 2375;

sub setup {
    my $self = shift;
    my @pkgs = qw(docker docker-buildx go1.26 openssl);
    push @pkgs, qw(docker-compose) unless is_sle("<16");
    $self->setup_pkgs(@pkgs);
    install_gotestsum;

    # On SLES 15-SP4 & 15-SP5, dockerd fails with:
    # invalid TLS configuration: failed to append certificates from PEM file: "/etc/docker/ca.pem"
    my $tls = is_sle("<15-SP6") ? 0 : 1;
    $port++ if $tls;

    configure_docker(selinux => 1, tls => $tls);

    run_command "docker run -d --name registry -p 5000:5000 registry.opensuse.org/opensuse/registry:2";

    # Some tests have /usr/local/go/bin/go hard-coded
    run_command 'ln -s /usr /usr/local/go';

    run_command "echo 127.0.0.1 registry >> /etc/hosts";

    $version = script_output "docker version --format '{{.Client.Version}}' 2>/dev/null", proceed_on_failure => 1;
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

    $firewall_backend = script_output "docker info -f '{{ .FirewallBackend.Driver }}' | awk -F+ '{ print \$1 }'";
    # Init Docker Swarm
    my $ip_addr = script_output("ip -j route get 8.8.8.8 | jq -Mr '.[0].prefsrc'");
    run_command "docker swarm init --advertise-addr $ip_addr" unless ($firewall_backend eq "nftables");
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
        TEST_DOCKER_HOST => "localhost:$port",
        DOCKER_CLI_E2E_PLUGINS_EXTRA_DIRS => "/var/tmp/cli/build/plugins-linux-$arch",
    );
    my $env = join " ", map { "$_=\"$env{$_}\"" } sort keys %env;

    my @xfails = (
        "github.com/docker/cli/e2e/global::TestTLSVerify",
    );
    push @xfails, (
        # These tests fail on SLES 15-SP7 due to SUSE patch
        "github.com/docker/cli/e2e/image::TestBuildFromContextDirectoryWithTag",
    ) if (is_sle("<16"));
    push @xfails, (
        "github.com/docker/cli/e2e/container::TestProcessTermination",
        "github.com/docker/cli/e2e/plugin::TestInstall",
    ) unless (is_x86_64);
    # Docker Swarm is not compatible with nftables
    push @xfails, (
        "github.com/docker/cli/e2e/stack::TestDeployWithNamedResources",
        "github.com/docker/cli/e2e/stack::TestRemove",
    ) if ($firewall_backend eq "nftables");

    run_timeout_command "$env gotestsum --junitfile cli.xml ./e2e/... -- &> cli.txt", no_assert => 1, timeout => 3000;
    upload_logs "cli.txt", failok => 1;
    die "Testsuite failed" if script_run("test -s cli.xml");
    patch_junit "docker", $version, "cli.xml", @xfails;
    parse_extra_log(XUnit => "cli.xml", timeout => 180);
}

sub cleanup {
    script_run "docker rm -vf registry";
    script_run "COMPOSE_PROJECT_NAME=clie2e COMPOSE_FILE=./e2e/compose-env.yaml docker compose down -v --rmi all";
    script_run "docker swarm leave -f" unless ($firewall_backend eq "nftables");
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
