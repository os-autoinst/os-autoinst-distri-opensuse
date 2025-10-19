# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Packages: docker
# Summary: Upstream moby e2e tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest', -signatures;
use testapi;
use serial_terminal qw(select_serial_terminal);
use version_utils;
use utils;
use Utils::Architectures;
use containers::bats;

my $version;
my @test_dirs;

sub setup {
    my $self = shift;
    my @pkgs = qw(containerd-ctr distribution-registry docker glibc-devel go1.24 make);
    $self->setup_pkgs(@pkgs);
    install_gotestsum;

    configure_docker;

    # We need ping from GNU inetutils
    run_command 'docker run --rm -it -v /usr/local/bin:/target:rw,z debian sh -c "apt update; apt install -y inetutils-ping; cp -v /bin/ping* /target"', timeout => 120;
    record_info "ping version", script_output("ping --version");

    # Tests use "ctr"
    run_command "cp /usr/sbin/containerd-ctr /usr/local/bin/ctr";

    # Unprivileged user for rootless docker tests
    run_command "useradd --create-home --gid docker unprivilegeduser";

    $version = script_output "docker version --format '{{.Client.Version}}'";
    $version =~ s/-ce$//;
    $version = "v$version";
    record_info "docker version", $version;

    patch_sources "moby", $version, "integration";

    # Build test helpers
    run_command "cp -f vendor.mod go.mod || true";
    run_command "cp -f vendor.sum go.sum || true";
    run_command '(cd testutil/fixtures/plugin/basic; go mod init docker-basic-plugin; go build -o $GOPATH/bin/docker-basic-plugin)';

    # Ignore the tests in these directories in integration/
    my @ignore_dirs = (
        "network",
        "networking",
        "plugin.*",
    );
    my $ignore_dirs = join "|", map { "integration/$_" } @ignore_dirs;
    if (my $test_dirs = get_var("DOCKER_TEST_DIRS", "")) {
        @test_dirs = split(/,/, $test_dirs);
    } else {
        # Adapted from https://build.opensuse.org/projects/openSUSE:Factory/packages/docker/files/docker-integration.sh
        @test_dirs = split(/\n/, script_output(qq(go list -test -f '{{- if ne .ForTest "" -}}{{- .Dir -}}{{- end -}}' ./integration/... | sed "s,^\$(pwd)/,," | grep -vxE '($ignore_dirs)')));
        push @test_dirs, "integration-cli" if is_x86_64;
    }

    # Preload Docker images used for testing
    my $frozen_images = script_output q(grep -oE '[[:alnum:]./_-]+:[[:alnum:]._-]+@sha256:[0-9a-f]{64}' Dockerfile | xargs echo);
    run_command "contrib/download-frozen-image-v2.sh /docker-frozen-images $frozen_images", timeout => 180;

    if (grep { $_ eq "integration-cli" } @test_dirs) {
        # integration-cli tests need an older cli version
        my $arch = get_var("ARCH");
        my $cliversion = get_var("DOCKER_CLIVERSION", script_output q(sed -n '/DOCKERCLI_INTEGRATION_VERSION=/s/.*=v//p' Dockerfile));
        run_command "curl -sSL https://download.docker.com/linux/static/stable/$arch/docker-$cliversion.tgz | tar zxvf - -C /var/tmp --strip-components 1 docker/docker";
    }
}

sub run {
    my $self = shift;
    select_serial_terminal;
    $self->setup;
    select_serial_terminal;

    my $firewall_backend = script_output "docker info -f '{{ .FirewallBackend.Driver }}' | awk -F+ '{ print \$1 }'";
    record_info "firewall backend", $firewall_backend;
    my $test_no_firewalld = ($firewall_backend eq "iptables") ? "true" : "";

    my %env = (
        DOCKER_FIREWALL_BACKEND => $firewall_backend,
        DOCKER_TEST_NO_FIREWALLD => $test_no_firewalld,
        TZ => "UTC",
    );

    my @xfails = (
        # Flaky tests
        "github.com/docker/docker/integration/service::TestServicePlugin",
    );
    push @xfails, (
        # These tests use amd64 images:
        "github.com/docker/docker/integration/image::TestAPIImageHistoryCrossPlatform",
    ) unless (is_x86_64);
    push @xfails, (
        # These tests are expected to fail in the deprecated integration-cli tests
        "github.com/docker/docker/integration-cli::TestDockerCLIAttachSuite",
        "github.com/docker/docker/integration-cli::TestDockerCLIAttachSuite/TestAttachAfterDetach",
        "github.com/docker/docker/integration-cli::TestDockerCLIAttachSuite/TestAttachDetach",
        "github.com/docker/docker/integration-cli::TestDockerCLIRestartSuite",
        "github.com/docker/docker/integration-cli::TestDockerCLIRestartSuite/TestRestartDisconnectedContainer",
        "github.com/docker/docker/integration-cli::TestDockerCLIRestartSuite/TestRestartPolicyAfterRestart",
        "github.com/docker/docker/integration-cli::TestDockerCLIRestartSuite/TestRestartPolicyOnFailure",
        "github.com/docker/docker/integration-cli::TestDockerCLIRestartSuite/TestRestartWithVolumes",
        "github.com/docker/docker/integration-cli::TestDockerCLIRmiSuite",
        "github.com/docker/docker/integration-cli::TestDockerCLIRmiSuite/TestRmiContainerImageNotFound",
        "github.com/docker/docker/integration-cli::TestDockerCLIRmiSuite/TestRmiForceWithExistingContainers",
        "github.com/docker/docker/integration-cli::TestDockerCLIRmiSuite/TestRmiImageIDForceWithRunningContainersAndMultipleTags",
        "github.com/docker/docker/integration-cli::TestDockerCLIRmiSuite/TestRmiUntagHistoryLayer",
    ) if (grep { $_ eq "integration-cli" } @test_dirs);

    my $tags = "apparmor selinux seccomp pkcs11";
    foreach my $dir (@test_dirs) {
        my $report = $dir =~ s|/|-|gr;
        $env{TEST_CLIENT_BINARY} = "/var/tmp/docker" if ($dir eq "integration-cli");
        my $env = join " ", map { "$_=\"$env{$_}\"" } sort keys %env;
        run_command "pushd $dir";
        run_command "$env gotestsum --junitfile $report.xml --format standard-verbose ./... -- -tags '$tags' |& tee -a /var/tmp/report.txt", timeout => 900;
        patch_junit "docker", $version, "$report.xml", @xfails;
        parse_extra_log(XUnit => "$report.xml");
        run_command "popd";
    }
    upload_logs("/var/tmp/report.txt");
}

sub cleanup {
    script_run "rm -f /usr/local/bin/{ctr,docker,ping} /var/tmp/docker";
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
