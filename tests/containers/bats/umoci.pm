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
use version_utils;
use version;
use containers::bats;

sub run_tests {
    my %params = @_;
    my $rootless = $params{rootless};

    my %env = (
        SOURCE_IMAGE => "/var/tmp/image",
        SOURCE_TAG => "latest",
        UMOCI => "/usr/bin/umoci",
    );

    my $log_file = "umoci-" . ($rootless ? "user" : "root");

    my @xfails = (
        "repack.bats::umoci {un,re}pack [xattrs]",
        "stat.bats::umoci stat [output snapshot: minimal image]",
    );

    my $ret = bats_tests($log_file, \%env, \@xfails, 1200);

    return ($ret);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my @pkgs = qw(attr diffutils file go1.25 go-md2man jq libcap-progs make moreutils python313-xattr runc skopeo umoci);
    $self->setup_pkgs(@pkgs);

    my $os_version = "openSUSE_Tumbleweed";
    if (is_sle) {
        $os_version = get_var("VERSION");
        $os_version =~ s/-SP/./;
    }
    run_command "zypper addrepo https://download.opensuse.org/repositories/home:/cyphar:/containers/$os_version/home:cyphar:containers.repo";
    run_command "zypper --gpg-auto-import-keys -n install --allow-vendor-change go-mtree";

    my $umoci_version = script_output("umoci --version | awk '{ print \$3; exit }'");
    $umoci_version = "v$umoci_version";
    record_info("umoci version", $umoci_version);

    switch_to_user;

    run_command 'skopeo copy docker://registry.opensuse.org/opensuse/tumbleweed:latest oci:/var/tmp/image:latest';

    patch_sources "umoci", $umoci_version, "test";
    run_command 'git submodule update --init hack/docker-meta-scripts';

    my $errors = 0;
    $errors += run_tests(rootless => 1) unless check_var('BATS_SKIP_USER', 'all');

    switch_to_root;

    $errors += run_tests(rootless => 0) unless check_var('BATS_SKIP_ROOT', 'all');

    die "umoci tests failed" if ($errors);
}

sub cleanup {
    script_run "rm -rf /var/tmp/image";
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
