# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: container-diff
# Summary: Print and save diffs between two cotaniners using container-diff tool
# Maintainer: qac team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use containers::common;
use containers::container_images;
use containers::urls 'get_image_uri';

sub run {
    my ($self) = @_;
    select_serial_terminal;
    my $docker = $self->containers_factory('docker');

    zypper_call("install container-diff") if (script_run("which container-diff") != 0);

    my $unreleased_image = get_image_uri(released => 0);
    my $released_image = get_image_uri();
    # container-diff
    my $image_file = $unreleased_image =~ s/\/|:/-/gr;
    my $container_diff_results = "/tmp/container-diff-$image_file.txt";
    assert_script_run("docker pull $unreleased_image", 360);
    assert_script_run("docker pull $released_image", 360);
    assert_script_run("container-diff diff daemon://$unreleased_image daemon://$released_image --type=rpm --type=file --type=size > $container_diff_results", 300);
    upload_logs("$container_diff_results");

    # Clean container
    $docker->cleanup_system_host();
}

1;
