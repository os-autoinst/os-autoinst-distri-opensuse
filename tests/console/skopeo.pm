# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test skopeo installation and basic usage
#    Cover the following aspects of skopeo:
#      * Inspecting a repository before pulling it
#      * Copy an image from Docker registry into an OCI image-spec
# Maintainer: Panagiotis Georgiadis <pgeorgiadis@suse.com>

use strict;
use warnings;
use base "consoletest";
use testapi;
use transactional_system 'trup_install';

sub run {
    select_console("root-console");

    record_info 'Test #1', 'Test: Installation';
    my $package = 'skopeo';
    trup_install($package);

    record_info 'Test #2', 'Test: inspecting a repository';
    assert_script_run('skopeo inspect docker://docker.io/opensuse');               # without tag
    assert_script_run('skopeo inspect docker://docker.io/opensuse:tumbleweed');    # with tag

    record_info 'Test #3', 'Test: Copying images';
    assert_script_run('mkdir folder');
    assert_script_run('skopeo copy docker://docker.io/opensuse:tumbleweed dir:folder',                        120);
    assert_script_run('skopeo copy docker://docker.io/opensuse:tumbleweed oci:opensuse_ocilayout:tumbleweed', 120);

}

1;
