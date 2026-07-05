# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Packages: podman
# Summary: Test podman e2e
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest', -signatures;
use testapi;
use serial_terminal qw(select_serial_terminal);
use power_action_utils 'power_action';
use version_utils;
use version;
use utils;
use containers::common qw(install_packages);
use containers::bats;

my $oci_runtime;
my $version;

sub setup {
    my $self = shift;
    my @pkgs = qw(aardvark-dns apache2-utils buildah catatonit docker glibc-devel-static go1.26 gpg2 jq libgpgme-devel
      libseccomp-devel make netavark openssl podman podman-remote runc skopeo socat sudo systemd-container xfsprogs);
    push @pkgs, qw(criu crun libcriu2) unless is_sle;
    $oci_runtime = get_var("OCI_RUNTIME", "runc");

    $self->setup_pkgs(@pkgs);
    select_serial_terminal;

    run_command "modprobe null_blk nr_devices=1 || true";

    # rootless user needed for these tests
    run_command "useradd -m containers";
    run_command "usermod --add-subuids 100000-165535 containers";
    run_command "usermod --add-subgids 100000-165535 containers";
    # Make /run/secrets directory available on containers
    run_command "echo /var/lib/empty:/run/secrets >> /etc/containers/mounts.conf";
    # The tests expect an exact list of unqualified-search-registries containing "quay.io" and we ship:
    # unqualified-search-registries = ["registry.opensuse.org", "registry.suse.com", "docker.io"]
    run_command "rm -f /etc/containers/registries.conf.d/00-suse-registries.conf";

    enable_docker;

    if (get_var("ROOTLESS")) {
        switch_to_user;
        run_command "podman system service --timeout=0 &";
    }

    $version = script_output q(podman --version | awk '{ print $3 }');
    $version = "v$version";
    record_info("version", $version);
    record_info("info", script_output("podman info -f json"));
    record_info("OCI features", script_output("$oci_runtime features"));
    record_info("OCI runtime", script_output("$oci_runtime --version"));

    # Download podman sources
    patch_sources "podman", $version, "test/e2e";
    # This test fails with:
    # Command exited 125 as expected, but did not emit 'failed to connect: dial tcp: lookup '
    run_command "rm -f test/e2e/image_scp_test.go";
    # https://github.com/containers/podman/pull/28266 can't be cleanly applied on 5.8.x
    run_command "rm -f test/e2e/run_aardvark_test.go" if (version->parse(numeric_version($version)) <= version->parse("5.9.0"));
}

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;
    $self->setup;

    run_command "cd /var/tmp/podman";

    my $quadlet = script_output "rpm -ql podman | grep podman/quadlet";

    my %env = (
        OCI_RUNTIME => $oci_runtime,
        PODMAN_BINARY => "/usr/bin/podman",
        PODMAN_REMOTE_BINARY => "/usr/bin/podman-remote",
        QUADLET_BINARY => "/usr/libexec/podman/quadlet",
        TESTFLAGS => "--junit-report=report.xml",
    );
    my $env = join " ", map { "$_=$env{$_}" } sort keys %env;

    my @xfails = (
        'Libpod Suite::[It] Podman pod create podman pod create --restart=on-failure',
        'Libpod Suite::[It] Podman run memory podman run memory test on oomkilled container',
    );
    push @xfails, (
        # Fixed in podman 5.6.1:
        # https://bugzilla.suse.com/show_bug.cgi?id=1249050 - podman passes volume options as bind mount options to runtime
        'Libpod Suite::[It] Podman run with volumes podman run with --mount and named volume with driver-opts',
        'Libpod Suite::[It] Podman run with volumes podman named volume copyup',
    ) if (version->parse(numeric_version($version)) < version->parse("5.6.1"));
    push @xfails, (
        # Fixed in podman 5.8.0 with https://github.com/containers/podman/pull/27333
        # Fails with "registry.access.redhat.com/*openshift*"
        'Libpod Suite::[It] Podman search podman search with wildcards',
    ) if (version->parse(numeric_version($version)) < version->parse("5.8.0"));
    push @xfails, (
        'Libpod Suite::[It] Verify podman containers.conf usage set .engine.remote=true',
    ) if (get_var("ROOTLESS"));
    push @xfails, (
        # We can't backport https://github.com/containers/podman/pull/27775 and this test may fail with:
        # Command exited 125 as expected, but did not emit 'gateway 192.168.1.1 not in subnet 10.11.12.0/24'
        'Libpod Suite::[It] Podman network create podman network create with invalid gateway for subnet',
    ) if (
        $oci_runtime eq "runc"
        && version->parse(numeric_version($version)) >= version->parse("5.8.2")
        && version->parse(numeric_version($version)) < version->parse("6.0")
    );
    # NOTE: Remove when criu > 4.2-2.1
    push @xfails, (
        "Libpod Suite::[It] Podman checkpoint podman checkpoint --create-image with running container",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint a container started with --rm",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint a container with volumes",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint a running container by id",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint a running container by name",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint all running container",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint and restore container with --file-locks",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint and restore container with root file-system changes",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint and restore container with root file-system changes using --ignore-rootfs during checkpoint",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint and restore container with root file-system changes using --ignore-rootfs during restore",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint and restore container with same IP",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint and restore dev/shm content",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint and restore dev/shm content with --export and --import",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint and run exec in restored container",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint container with --pre-checkpoint",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint container with --pre-checkpoint and export (migration)",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint container with export (migration)",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint container with export (migration) and --ipc host",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint container with export and different compression algorithms",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint container with export and statistics",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint container with export and verify runtime",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint latest running container",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint with --leave-running",
        "Libpod Suite::[It] Podman checkpoint podman pause a checkpointed container by id",
        "Libpod Suite::[It] Podman checkpoint podman restore multiple containers from multiple checkpoint images",
        "Libpod Suite::[It] Podman checkpoint podman restore multiple containers from single checkpoint image",
        "Libpod Suite::[It] Podman checkpoint podman run with checkpoint image",
        # Seen with crun:
        "Libpod Suite::[It] Podman checkpoint podman checkpoint container with export and verify non-default runtime",
        "Libpod Suite::[It] Podman checkpoint podman checkpoint container with export and try to change the runtime",
    ) if (is_tumbleweed);

    # Skip remoteintegration on SLES as it panics with:
    # Too many RemoteSocket collisions [PANICKED] Test Panicked
    my $default_targets = "localintegration";
    # XXX: Temporarily turn this off for the time being until unknown openQA parsing issue is solved.
    # $default_targets .= " remoteintegration" unless (is_sle || get_var("ROOTLESS"));
    my @targets = split('\s+', get_var('RUN_TESTS', $default_targets));
    foreach my $target (@targets) {
        run_timeout_command "$env make $target &> $target.txt", no_assert => 1, timeout => 3000;
        upload_logs "$target.txt";
        assert_script_run "mv report.xml $target.xml";
        die "Testsuite failed" if script_run("test -s $target.xml");
        patch_junit "podman", $version, "$target.xml", @xfails;
        parse_extra_log(XUnit => "$target.xml", timeout => 300);
    }
}

sub post_fail_hook {
    bats_post_hook;
    cleanup_podman;
    run_command 'kill %1; kill -9 %1 || true';
}

sub post_run_hook {
    bats_post_hook;
    cleanup_podman;
    run_command 'kill %1; kill -9 %1 || true';
}

1;
