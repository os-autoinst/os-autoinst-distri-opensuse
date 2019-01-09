# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test umoci installation and basic usage
#    Cover the following aspects of umoci:
#      * Inspecting a repository before pulling it
#      * Copy an image from Docker registry into an OCI image-spec
#      * Unpack and repack (root/rootless) images
# Maintainer: Panagiotis Georgiadis <pgeorgiadis@suse.com>

use strict;
use base "consoletest";
use testapi;
use transactional_system 'trup_install';

sub run {
    select_console("root-console");

    record_info 'Test #1', 'Test: Installation';
    trup_install('umoci');

    record_info 'Setup', 'Requirements';
    assert_script_run('mkdir test_umoci && cd test_umoci');
    assert_script_run('skopeo copy docker://docker.io/opensuse/tumbleweed oci:opensuse:tumbleweed', 600);

    record_info 'Test #2', 'Test: Creating an image';
    assert_script_run('umoci init --layout new_image');          # without tag
    assert_script_run('umoci new --image new_image:new_tag');    # with tag

    record_info 'Test #3', 'Test: Unpacking an image';
    assert_script_run('umoci unpack --image opensuse:tumbleweed bundle');
    assert_script_run("ls -l bundle | egrep 'config.json|rootfs|sha256|umoci.json'");
    assert_script_run("cat bundle/rootfs/etc/os-release | grep 'Tumbleweed'");

    record_info 'Test #4', 'Test: Unpacking a rootless image';
    assert_script_run('umoci unpack --rootless --image opensuse:tumbleweed bundle2');

    record_info 'Test #5', 'Test: Repacking both images';
    assert_script_run('umoci repack --image opensuse:new bundle');
    assert_script_run('umoci repack --image opensuse:new bundle2');    # rootless image

    record_info 'Clean', 'Leave it clean for other tests';
    script_run('cd');
}

1;
