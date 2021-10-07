# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: container-diff
# Summary: Print and save diffs between two cotaniners using container-diff tool
# Maintainer: qac team <qa-c@suse.de>

use base 'consoletest';
use testapi;
use utils;
use strict;
use warnings;
use containers::common;
use containers::container_images;
use containers::urls 'get_suse_container_urls';
use version_utils qw(is_sle get_os_release);
use containers::engine;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    my $docker = containers::engine::docker->new();
    my ($running_version, $sp, $host_distri) = get_os_release;

    install_docker_when_needed($host_distri);
    $docker->configure_insecure_registries() if is_sle();
    zypper_call("install container-diff")    if (script_run("which container-diff") != 0);

    my ($untested_images, $released_images) = get_suse_container_urls();
    # container-diff
    for my $i (@{$untested_images}) {
        my $image_file             = $untested_images->[$i] =~ s/\/|:/-/gr;
        my $container_diff_results = "/tmp/container-diff-$image_file.txt";
        assert_script_run("docker pull $untested_images->[$i]", 360);
        assert_script_run("docker pull $released_images->[$i]", 360);
        assert_script_run("container-diff diff daemon://$untested_images->[$i] daemon://$released_images->[$i] --type=rpm --type=file --type=size > $container_diff_results", 300);
        upload_logs("$container_diff_results");
        ensure_container_rpm_updates("$container_diff_results");
    }

    # Clean container
    $docker->cleanup_system_host();
}

1;
