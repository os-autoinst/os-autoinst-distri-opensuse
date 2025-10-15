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
    my @pkgs = qw(docker docker-compose go1.24 jq make);
    $self->setup_pkgs(@pkgs);

    # The tests assume a vanilla configuration
    run_command "mv -f /etc/docker/daemon.json{,.bak}";
    run_command "mv -f /etc/sysconfig/docker{,.bak}";
    # The tests use both network & Unix socket
    run_command q(echo 'DOCKER_OPTS="-H 0.0.0.0:2375 -H unix:///var/run/docker.sock --insecure-registry registry:5000 --experimental"' > /etc/sysconfig/docker);
    # The tests assume the legacy builder
    run_command "mv /usr/lib/docker/cli-plugins/docker-buildx{,.bak}";
    run_command "systemctl enable docker";
    run_command "systemctl restart docker";
    record_info "docker info", script_output("docker info");

    run_command "docker run -d --name registry -p 5000:5000 registry.opensuse.org/opensuse/registry:2";

    # Install test dependencies
    if (is_x86_64) {
        my $notary_version = "v0.6.1";
        my $url = "https://github.com/theupdateframework/notary/releases/download/$notary_version/notary-Linux-amd64";
        run_command "curl -sSLo /usr/local/bin/notary $url";
        run_command "chmod +x /usr/local/bin/notary";
    }

    # We need gotestsum to parse "go test" and create JUnit XML output
    run_command 'export GOPATH=$HOME/go';
    run_command 'export PATH=$PATH:$GOPATH/bin';
    run_command 'go install gotest.tools/gotestsum@v1.13.0';
    # Some tests have /usr/local/go/bin/go hard-coded
    run_command 'ln -s /usr /usr/local/go';

    my $ip_addr = script_output("ip -j route get 8.8.8.8 | jq -Mr '.[0].prefsrc'");
    run_command "echo $ip_addr notary-server >> /etc/hosts";
    run_command "echo $ip_addr evil-notary-server >> /etc/hosts";
    run_command "echo 127.0.0.1 registry >> /etc/hosts";

    $version = script_output "docker version --format '{{.Client.Version}}'";
    $version =~ s/-ce$//;
    $version = "v$version";
    record_info "docker version", $version;

    patch_sources "cli", $version, "e2e";

    run_command "cp vendor.mod go.mod";
    run_command "cp vendor.sum go.sum";

    # Trust this certificate to test notary
    run_command "cp e2e/testdata/notary/root-ca.cert /etc/pki/trust/anchors/";
    run_command "update-ca-certificates";

    # We don't test Docker Content Trust
    run_command "rm -rf e2e/trust";
    run_command "TARGET=build/ ./scripts/build/plugins e2e/cli-plugins/plugins/*";

    # Fetch needed images
    run_command "./scripts/test/e2e/load-image";
    # Init Docker Swarm
    run_command "docker swarm init --advertise-addr $ip_addr";
    # Init Docker Compose
    run_command "COMPOSE_PROJECT_NAME=clie2e COMPOSE_FILE=./e2e/compose-env.yaml docker compose up --build -d registry notary-server evil-notary-server";
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
        # Expected failures from Docker Content Trust
        "github.com/docker/cli/e2e/container::TestTrustedCreateFromBadTrustServer",
        "github.com/docker/cli/e2e/container::TestTrustedRunFromBadTrustServer",
    );
    # These require notary which is currently shipped for x86_64 only
    push @xfails, (
        "github.com/docker/cli/e2e/image::TestPushWithContentTrustReleasesDelegationOnly",
        "github.com/docker/cli/e2e/image::TestPushWithContentTrustSignsAllFirstLevelRolesWeHaveKeysFor",
        "github.com/docker/cli/e2e/image::TestPushWithContentTrustSignsForRolesWithKeysAndValidPaths",
    ) unless (is_x86_64);

    patch_junit "docker", $version, "cli.xml", @xfails;
    parse_extra_log(XUnit => "cli.xml");
    upload_logs("cli.txt");
}

sub cleanup() {
    script_run "docker rm -vf registry";
    script_run "COMPOSE_PROJECT_NAME=clie2e COMPOSE_FILE=./e2e/compose-env.yaml docker compose down -v --rmi all";
    script_run "docker swarm leave -f";
    script_run "docker rmi -f \$(docker images -q)";
    script_run "docker volume prune -a -f";
    script_run "docker system prune -a -f";
    script_run "mv -f /etc/docker/daemon.json{.bak,}";
    script_run "mv -f /etc/sysconfig/docker{.bak,}";
    script_run "mv -f /usr/lib/docker/cli-plugins/docker-buildx{.bak,}";
    systemctl "restart docker";
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
