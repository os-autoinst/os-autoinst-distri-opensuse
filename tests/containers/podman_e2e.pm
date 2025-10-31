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
use utils;
use containers::common qw(install_packages);
use containers::bats;

my $oci_runtime;
my $version;

sub setup {
    my $self = shift;
    my @pkgs = qw(aardvark-dns apache2-utils buildah catatonit glibc-devel-static go1.24 gpg2 jq libgpgme-devel
      libseccomp-devel make netavark openssl podman podman-remote skopeo socat sudo systemd-container xfsprogs);
    push @pkgs, qw(criu libcriu2) unless is_sle;
    $oci_runtime = get_var("OCI_RUNTIME", "runc");
    push @pkgs, $oci_runtime;

    $self->setup_pkgs(@pkgs);
    select_serial_terminal;

    # Workaround for https://bugzilla.opensuse.org/show_bug.cgi?id=1248988 - catatonit missing in /usr/libexec/podman/
    if (is_sle) {
        my $libdir = is_sle("<16") ? "lib" : "libexec";
        run_command "ln -f /usr/bin/catatonit /usr/$libdir/podman/catatonit";
    }
    # rootless user needed for these tests
    run_command "useradd -m containers";
    run_command "usermod --add-subuids 100000-165535 containers";
    run_command "usermod --add-subgids 100000-165535 containers";
    # Make /run/secrets directory available on containers
    run_command "echo /var/lib/empty:/run/secrets >> /etc/containers/mounts.conf";

    if (get_var("ROOTLESS")) {
        switch_to_user;
        run_command "podman system service --timeout=0 &";
    }

    $version = script_output q(podman --version | awk '{ print $3 }');
    $version = "v$version";
    record_info("version", $version);
    record_info("info", script_output("podman info -f json"));
    record_info("OCI runtime", script_output("$oci_runtime --version"));

    # Download podman sources
    patch_sources "podman", $version, "test/e2e";
    # This test fails with:
    # Command exited 125 as expected, but did not emit 'failed to connect: dial tcp: lookup '
    run_command "rm -f test/e2e/image_scp_test.go";
}

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;
    $self->setup;

    assert_script_run "cd /var/tmp/podman";

    my $quadlet = script_output "rpm -ql podman | grep podman/quadlet";

    my %env = (
        OCI_RUNTIME => $oci_runtime,
        PODMAN_BINARY => "/usr/bin/podman",
        PODMAN_REMOTE_BINARY => "/usr/bin/podman-remote",
        QUADLET_BINARY => "/usr/libexec/podman/quadlet",
        TESTFLAGS => "--junit-report=report.xml",
    );
    my $env = join " ", map { "$_=$env{$_}" } sort keys %env;

    my @xfails = ();
    push @xfails, (
        # Fixed in podman 5.6.1:
        # https://bugzilla.suse.com/show_bug.cgi?id=1249050 - podman passes volume options as bind mount options to runtime
        'Libpod Suite::[It] Podman run with volumes podman run with --mount and named volume with driver-opts',
        'Libpod Suite::[It] Podman run with volumes podman named volume copyup',
    ) unless (is_tumbleweed);
    push @xfails, (
        'Libpod Suite::[It] Verify podman containers.conf usage set .engine.remote=true',
    ) if (get_var("ROOTLESS"));
    # These tests fail as rootless/remote only
    my @rootless_remote_xfails = (
        'Libpod Suite::[It] Podman build podman build --build-context: Mixed source',
        'Libpod Suite::[It] Podman build podman build --build-context: URL source',
        'Libpod Suite::[It] Podman build podman build http proxy test',
        'Libpod Suite::[It] Podman build podman build relay exit code to process',
        'Libpod Suite::[It] Podman build podman remote test container/docker file is not at root of context dir',
        'Libpod Suite::[It] Podman pod create podman create pod with --hosts-file --hosts-file= falls back to containers.conf',
        'Libpod Suite::[It] Podman pod create podman create pod with --hosts-file --hosts-file=image',
        'Libpod Suite::[It] Podman pod create podman create pod with --hosts-file --hosts-file=none',
        'Libpod Suite::[It] Podman pod create podman create pod with --hosts-file --hosts-file=path',
        'Libpod Suite::[It] Podman prune podman system image prune unused images',
        'Libpod Suite::[It] Podman prune podman system prune --build clean up after terminated build',
        'Libpod Suite::[It] Podman run podman run user capabilities test with image',
        'Libpod Suite::[It] Podman run podman run with --hosts-file --hosts-file= falls back to containers.conf',
        'Libpod Suite::[It] Podman run podman run with --hosts-file --hosts-file=image',
        'Libpod Suite::[It] Podman run podman run with --hosts-file --hosts-file=none',
        'Libpod Suite::[It] Podman run podman run with --hosts-file --hosts-file=path',
        'Libpod Suite::[It] Podman run podman run with --hosts-file should fail with --no-hosts',
        'Libpod Suite::[It] Podman run podman run with --hosts-file works with pod without an infra-container',
        'Libpod Suite::[It] Verify podman containers.conf usage base_hosts_file in containers.conf base_hosts_file=none should not use any hosts files',
'Libpod Suite::[It] Verify podman containers.conf usage base_hosts_file in containers.conf base_hosts_file=image should use the hosts file from the container image',
'Libpod Suite::[It] Verify podman containers.conf usage base_hosts_file in containers.conf base_hosts_file=path should use the hosts file from the file path',
    );

    # Skip remoteintegration on SLES as it panics with:
    # Too many RemoteSocket collisions [PANICKED] Test Panicked
    my $default_targets = "localintegration";
    $default_targets .= " remoteintegration" unless is_sle;
    my @targets = split('\s+', get_var('RUN_TESTS', $default_targets));
    foreach my $target (@targets) {
        run_command "env $env make $target &> $target.txt || true", timeout => 1800;
        script_run "mv report.xml $target.xml";
        push @xfails, @rootless_remote_xfails if ($target eq "remoteintegration" && get_var("ROOTLESS"));
        patch_junit "podman", $version, "$target.xml", @xfails;
        parse_extra_log(XUnit => "$target.xml");
        upload_logs("$target.txt");
    }
}

sub post_fail_hook {
    cleanup_podman;
    run_command 'kill %1; kill -9 %1 || true';
    bats_post_hook;
}

sub post_run_hook {
    cleanup_podman;
    run_command 'kill %1; kill -9 %1 || true';
    bats_post_hook;
}

1;
