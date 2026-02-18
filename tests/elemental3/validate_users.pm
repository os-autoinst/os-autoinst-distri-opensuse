# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test user and group existence, group membership, and user shell access
#
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use base qw(opensusebasetest);
use testapi;
use serial_terminal qw(select_serial_terminal);

sub run {
    select_serial_terminal();

    # User and group details
    my $test_user = get_var('TEST_USER', 'qetest');
    my $test_group = get_var('TEST_GROUP', 'qetestgroup');

    record_info('User Check', "Verifying user '$test_user' and group '$test_group'");

    # Verify 'qetest' user exists
    assert_script_run("id $test_user", fail_message => "User '$test_user' does not exist!");

    # Verify 'qetestgroup' exists
    assert_script_run("getent group $test_group", fail_message => "Group '$test_group' does not exist!");

    # Verify 'qetest' is a member of qetestgroup
    assert_script_run("id -Gn $test_user | grep -w $test_group", fail_message => "User '$test_user' is NOT a member of '$test_group'!");

    # Verify Shell Access
    assert_script_run("su - $test_user -c 'whoami' | grep $test_user", fail_message => "Could not verify shell access for '$test_user'");
}

sub test_flags {
    return {fatal => 1};
}

1;
