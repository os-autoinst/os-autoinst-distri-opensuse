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
#      * Installation of yast2-users to create normal user
#      * Copy an image from Docker registry into an OCI image-spec
#      * Unpack rootless OCI image
#      * Run an OCI container
#      * lifecycle functions (create, start, kill, delete)
# Maintainer: Panagiotis Georgiadis <pgeorgiadis@suse.com>

use strict;
use base "consoletest";
use testapi;
use caasp;

sub run {
    select_console("root-console");

    record_info 'Setup', 'Requirements';
    trup_install('skopeo umoci runc yast2-users');

    # Create the user and add him to 'tty' group
    my $pass = $testapi::password;
    my $user = $testapi::username;
    assert_script_run("yast2 users add username=$user password=$pass grouplist=users,tty");

    # Change from 'root' into 'normal user'
    select_console("user-console");
    assert_script_run('mkdir test_rootless && cd test_rootless');
    assert_script_run('skopeo copy docker://docker.io/opensuse/tumbleweed oci:opensuse:tumbleweed', 600);
    assert_script_run('umoci unpack --rootless --image opensuse:tumbleweed bundle');

    $self->setup_container_in_background();

    record_info 'Test #2', 'Run OCI container (detached)';
    # construct the runc parameters for rootless access
    $runc = "/usr/sbin/runc --root /tmp/$user";
    $self->runc_test();
    record_info 'Clean', 'Leave it clean for other tests';
    script_run('cd');
    select_console("root-console");
}

1;
