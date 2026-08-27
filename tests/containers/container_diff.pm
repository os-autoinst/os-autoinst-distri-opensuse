# SUSE's openQA tests
#
# Copyright 2020-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: container-diff
# Summary: Print and save diffs between two containers using container-diff tool
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use containers::common;
use containers::container_images;
use containers::urls 'get_image_uri';
use version_utils qw(is_leap is_sle);

sub run {
    my ($self) = @_;
    select_serial_terminal;
    my $docker = $self->containers_factory('docker');

    # Not in the main repo, use it from the devel one for this test.
    # Prio 150 to only use this repo for packages not available elsewhere.
    zypper_call('addrepo -fG -p 150 obs://Virtualization:containers/' . get_required_var('VERSION') . ' containers') if is_leap("16.0+");

    zypper_call("install container-diff") if (script_run("which container-diff") != 0);

    # Authenticate against registry.suse.com before pulling the released
    # LTSS image (bsc#1274889). Avoids "docker login -u/-p", which would
    # print the credentials in the test logs.
    if (is_sle("=12-sp5")) {
        assert_script_run('mkdir -p ~/.docker');
        assert_script_run(
            q{printf '{"auths":{"registry.suse.com":{"auth":"%s"}}}' "$(awk -F= '/^username/{u=$2} /^password/{p=$2} END{printf "%s:%s", u, p}' /etc/zypp/credentials.d/SCCcredentials | base64 -w0)" > ~/.docker/config.json}
        );
    }

    my $unreleased_image = get_image_uri(released => 0);
    my $released_image = get_image_uri(released => 1);
    # container-diff
    my $image_file = $unreleased_image =~ s/\/|:/-/gr;
    my $container_diff_results = "/tmp/container-diff-$image_file.txt";
    assert_script_run("docker pull $unreleased_image", 360);
    assert_script_run("docker pull $released_image", 360);
    assert_script_run("container-diff diff daemon://$released_image daemon://$unreleased_image --type=rpm --type=file --type=size > $container_diff_results", 300);
    upload_logs("$container_diff_results");

    # Clean container
    $docker->cleanup_system_host();
}

1;
