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
use warnings;
use base "consoletest";
use testapi;
use transactional_system 'trup_install';

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

    # Modify the configuration to run the container in background
    script_run('cd bundle && cp config.json config.json.backup');
    assert_script_run("sed -i -e '/\"terminal\":/ s/: .*/: false,/' config.json");
    assert_script_run("sed -i -e 's/\"\\/bin\\/bash\"/\"echo\", \"42km\"/' config.json");

    record_info 'Test #2', 'Run OCI container (detached)';
    # construct the runc parameters for rootless access
    my $runc = "/usr/sbin/runc --root /tmp/$user";
    assert_script_run("$runc run marathon | grep 42km");
    # Restore the default configuration
    assert_script_run('mv config.json.backup config.json');
    assert_script_run("sed -i -e '/\"terminal\":/ s/: .*/: false,/' config.json");
    assert_script_run("sed -i -e 's/\"\\/bin\\/bash\"/\"sleep\", \"120\"/' config.json");

    # Container Lifecycle
    record_info 'Test #3', 'Test: Create a container';
    assert_script_run("$runc create life");
    assert_script_run("$runc state life | grep status | grep created");
    record_info 'Test #4', 'Test: List containers';
    assert_script_run("$runc list | grep life");
    record_info 'Test #5', 'Test: Start a container';
    assert_script_run("$runc start life");
    assert_script_run("$runc state life | grep running");
    record_info 'Test #6', 'Test: Stop a container';
    assert_script_run("$runc kill life KILL");
    assert_script_run("$runc state life | grep stopped");
    record_info 'Test #7', 'Test: Delete a container';
    assert_script_run("$runc delete life");
    assert_script_run("! $runc state life");

    record_info 'Clean', 'Leave it clean for other tests';
    script_run('cd');
    select_console("root-console");
}

1;
