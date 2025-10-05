# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: umoci
# Summary: Upstream umoci integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use containers::bats;

sub run_tests {
    my %params = @_;
    my ($rootless, $skip_tests) = ($params{rootless}, $params{skip_tests});

    return if ($skip_tests eq "all");

    my %env = (
        SOURCE_IMAGE => "/var/tmp/image",
        UMOCI => "/usr/bin/umoci",
    );

    my $log_file = "umoci-" . ($rootless ? "user" : "root");

    my $ret = bats_tests($log_file, \%env, $skip_tests, 1200);

    return ($ret);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my @pkgs = qw(attr diffutils file go1.24 go-md2man jq libcap-progs make moreutils python313-xattr runc skopeo umoci);
    $self->setup_pkgs(@pkgs);

    run_command "zypper addrepo https://download.opensuse.org/repositories/home:/cyphar:/containers/openSUSE_Tumbleweed/home:cyphar:containers.repo";
    run_command "zypper --gpg-auto-import-keys -n install --allow-vendor-change go-mtree";

    my $umoci_version = script_output("umoci --version | awk '{ print \$3; exit }'");
    $umoci_version = "v$umoci_version";
    record_info("umoci version", $umoci_version);

    switch_to_user;

    run_command 'skopeo copy docker://registry.opensuse.org/opensuse/tumbleweed:latest oci:/var/tmp/image';

    patch_sources "umoci", $umoci_version, "test";
    run_command 'git submodule update --init hack/docker-meta-scripts';

    my $errors = run_tests(rootless => 1, skip_tests => get_var('BATS_SKIP_USER', ''));

    switch_to_root;

    $errors += run_tests(rootless => 0, skip_tests => get_var('BATS_SKIP_ROOT', ''));

    die "umoci tests failed" if ($errors);
}

sub cleanup {
    script_run "rm -rf /var/tmp/image";
}

sub post_fail_hook {
    cleanup;
    bats_post_hook;
}

sub post_run_hook {
    cleanup;
    bats_post_hook;
}

1;
