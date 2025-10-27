# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Packages: docker
# Summary: Upstream moby e2e tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest', -signatures;
use testapi;
use serial_terminal;
use version_utils;
use utils;
use Utils::Architectures;
use containers::bats;

my $version;
my @test_dirs;

sub setup {
    my $self = shift;
    my @pkgs = qw(containerd-ctr distribution-registry docker docker-buildx docker-rootless-extras glibc-devel go1.24 rootlesskit selinux-tools);
    $self->setup_pkgs(@pkgs);

    configure_docker(selinux => 1, tls => 0);

    # We need ping from GNU inetutils
    run_command 'docker run --rm -it -v /usr/local/bin:/target:rw,z debian sh -c "apt update; apt install -y inetutils-ping; cp -vp /bin/ping* /target"', timeout => 120;
    record_info "ping version", script_output("ping --version");

    # Tests use "ctr"
    run_command "cp /usr/sbin/containerd-ctr /usr/local/bin/ctr";

    $version = script_output "docker version --format '{{.Client.Version}}'";
    $version =~ s/-ce$//;
    $version = "v$version";
    record_info "docker version", $version;

    run_command "ln -s /var/tmp/docker-frozen-images /";

    configure_rootless_docker if get_var("ROOTLESS");

    install_gotestsum;

    patch_sources "moby", $version, "integration";

    # "unprivilegeduser" is hard-coded in the tests
    run_command qq(find -name '*.go' -exec sed -i 's/"unprivilegeduser"/"$testapi::username"/g' {} +) if get_var("ROOTLESS");

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
    if (my $test_dirs = get_var("RUN_TESTS", "")) {
        @test_dirs = split(/,/, $test_dirs);
    } else {
        # Adapted from https://build.opensuse.org/projects/openSUSE:Factory/packages/docker/files/docker-integration.sh
        @test_dirs = split(/\n/, script_output(qq(go list -test -f '{{- if ne .ForTest "" -}}{{- .Dir -}}{{- end -}}' ./integration/... | sed "s,^\$(pwd)/,," | grep -vxE '($ignore_dirs)')));
    }

    # Preload Docker images used for testing
    my $frozen_images = script_output q(grep -oE '[[:alnum:]./_-]+:[[:alnum:]._-]+@sha256:[0-9a-f]{64}' Dockerfile | xargs echo);
    run_command "contrib/download-frozen-image-v2.sh /var/tmp/docker-frozen-images $frozen_images", timeout => 180;

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

    my $firewall_backend = script_output "docker info -f '{{ .FirewallBackend.Driver }}' | awk -F+ '{ print \$1 }'";
    record_info "firewall backend", $firewall_backend;
    my $test_no_firewalld = ($firewall_backend eq "iptables") ? "true" : "";

    my %env = (
        DOCKER_FIREWALL_BACKEND => $firewall_backend,
        DOCKER_ROOTLESS => get_var("ROOTLESS", ""),
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
    cleanup_rootless_docker if get_var("ROOTLESS");
    select_serial_terminal;
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
