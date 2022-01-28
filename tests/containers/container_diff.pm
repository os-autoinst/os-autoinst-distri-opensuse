# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: container-diff
# Summary: Print and save diffs between two cotaniners using container-diff tool
# Maintainer: qac team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use utils;
use containers::common;
use containers::container_images;
use containers::urls 'get_suse_container_urls';

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    my $docker = $self->containers_factory('docker');

    zypper_call("install container-diff") if (script_run("which container-diff") != 0);

    my ($testing_images, $released_images) = get_suse_container_urls();
    # container-diff
    for my $i (@{$testing_images}) {
        my $image_file = $testing_images->[$i] =~ s/\/|:/-/gr;
        my $container_diff_results = "/tmp/container-diff-$image_file.txt";
        assert_script_run("docker pull $testing_images->[$i]", 360);
        assert_script_run("docker pull $released_images->[$i]", 360);
        assert_script_run("container-diff diff daemon://$testing_images->[$i] daemon://$released_images->[$i] --type=rpm --type=file --type=size > $container_diff_results", 300);
        upload_logs("$container_diff_results");
    }

    # Clean container
    $docker->cleanup_system_host();
}

1;
