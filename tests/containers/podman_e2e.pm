# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Packages: python3-docker & python3-podman
# Summary: Test podman & docker python packages
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
    run_command "cp -f /usr/bin/catatonit /usr/libexec/podman/catatonit";
    # rootless user needed for these tests
    run_command "useradd -m containers";
    run_command "usermod --add-subuids 100000-165535 containers";
    run_command "usermod --add-subgids 100000-165535 containers";
    # Make /run/secrets directory available on containers
    run_command "echo /var/lib/empty:/run/secrets >> /etc/containers/mounts.conf";

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

    assert_script_run "curl -o /usr/local/bin/patch_junit " . data_url("containers/patch_junit.py");
    assert_script_run "chmod +x /usr/local/bin/patch_junit";
}

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;

    $self->setup;
    select_serial_terminal;

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

    # mapping of known expected failures
    my @xfails = ();
    unless (is_tumbleweed) {
        # Fixed in podman 5.6.1:
        # https://bugzilla.suse.com/show_bug.cgi?id=1249050 - podman passes volume options as bind mount options to runtime
        push @xfails, (
            'localintegration::[It] Podman run with volumes podman run with --mount and named volume with driver-opts',
            'remoteintegration::[It] Podman run with volumes podman run with --mount and named volume with driver-opts',
            'localintegration::[It] Podman run with volumes podman named volume copyup',
            'remoteintegration::[It] Podman run with volumes podman named volume copyup',
        );
    }

    my @targets = split('\s+', get_var('PODMAN_TARGETS', 'localintegration remoteintegration'));
    foreach my $target (@targets) {
        run_command "env $env make $target &> $target.txt || true", timeout => 1800;
        script_run "mv report.xml $target.xml";
        my $xfails = join(' ', map { "\"$_\"" } @xfails);
        assert_script_run "patch_junit $target.xml $xfails";
        patch_junit "podman", $version, "$target.xml";
        parse_extra_log(XUnit => "$target.xml");
        upload_logs("$target.txt");
    }
}

sub post_fail_hook {
    bats_post_hook;
}

sub post_run_hook {
    bats_post_hook;
}

1;
