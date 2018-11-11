# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test runc installation and basic usage
#    Cover the following aspects of umoci:
#      * Installation of runc
#      * Run an OCI container
#      * Complete lifecycle (create, start, pause, resume, kill, delete)
# Maintainer: Panagiotis Georgiadis <pgeorgiadis@suse.com>

use strict;
use base "consoletest";
use testapi;
use caasp;

sub run {
    select_console("root-console");
    record_info 'Test #1', 'Test: Installation';
    trup_install('runc skopeo umoci');

    record_info 'Setup', 'Requirements';
    assert_script_run('mkdir test_runc && cd test_runc');
    assert_script_run('skopeo copy docker://docker.io/opensuse/tumbleweed oci:opensuse:tumbleweed', 600);
    assert_script_run('umoci unpack --image opensuse:tumbleweed bundle');
    $self->setup_container_in_background();

    record_info 'Test #2', 'Run OCI container (detached)';
    $self->runc_test();
    record_info 'Test #8', 'Test: Stop a container';
    assert_script_run("$runc kill life KILL");
    assert_script_run("$runc state life | grep stopped");
    record_info 'Test #9', 'Test: Delete a container';
    assert_script_run("$runc delete life");
    assert_script_run("! $runc state life");

    record_info 'Clean', 'Leave it clean for other tests';
    script_run('cd');
    script_run('rm -r test_runc');
}

1;
