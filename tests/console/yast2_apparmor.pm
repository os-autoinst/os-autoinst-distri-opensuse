# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: check configuration of apparmor, add and delete apparmor profiles
# Maintainer: Zaoliang Luo <zluo@suse.de>

use strict;
use base "console_yasttest";
use testapi;



sub run {

    select_console 'root-console';

    # install yast2_apparmor package at first
    assert_script_run("/usr/bin/zypper -n -q in yast2-apparmor");

    # start apparmor configuration
    script_run("yast2 apparmor; echo yast2-apparmor-status-\$? > /dev/$serialdev", 0);
    # check Apparmor Configuration is opened
    assert_screen 'yast2_apparmor';
    send_key 'ret';

    assert_screen [qw(yast2_apparmor_disabled yast2_apparmor_enabled)];
    if (match_has_tag 'yast2_apparmor_disabled') {
        send_key 'alt-e';
    }
    assert_screen 'yast2_apparmor_enabled';
    # part 1: open profile mode configuration and check toggle/show all profiles
    send_key 'alt-n';
    assert_screen 'yast2_apparmor_profile_mode_configuration';
    send_key 'alt-o';
    assert_screen 'yast2_apparmor_profile_mode_configuration_show_all';
    wait_screen_change { send_key 'tab' };
    wait_screen_change { send_key 'down' };
    send_key 'alt-t';
    assert_screen 'yast2_apparmor_profile_mode_configuration_toggle';
    wait_screen_change { send_key 'alt-b' };

    # close apparmor configuration
    wait_screen_change { send_key 'alt-d' };
    # increase value for timeout to 200 seconds
    wait_serial("yast2-apparmor-status-0", 200) || die "'yast2 apparmor' didn't finish";
    assert_script_run("systemctl show -p ActiveState apparmor.service | grep ActiveState=active");

    # part 2: start apparmor configuration again
    script_run("yast2 apparmor; echo yast2-apparmor-status-\$? > /dev/$serialdev", 0);
    assert_screen 'yast2_apparmor';
    send_key 'down';
    assert_screen 'yast2_apparmor_configuration_manage_existing_profiles';
    send_key 'ret';
    assert_screen 'yast2_apparmor_configuration_manage_existing_profiles_edit_add';
    wait_screen_change { send_key 'alt-i' };
    wait_screen_change { send_key 'alt-a' };
    send_key 'alt-f';
    assert_screen 'yast2_apparmor_configuration_manage_existing_profiles_edit_add_file';
    wait_screen_change { send_key 'ret' };
    wait_screen_change { send_key 'alt-e' };
    type_string 'I_added_this_profile';
    wait_screen_change { send_key 'alt-p' };
    wait_screen_change { send_key 'spc' };
    assert_screen 'yast2_apparmor_configuration_manage_existing_profiles_edit_add_file_permissions_read';
    wait_screen_change { send_key 'down' };
    wait_screen_change { send_key 'spc' };
    assert_screen 'yast2_apparmor_configuration_manage_existing_profiles_edit_add_file_permissions_write';

    # confirm with cancel
    wait_screen_change { send_key 'alt-c' };

    # now add a directory with permission for read and write
    wait_screen_change { send_key 'alt-a' };
    wait_screen_change { send_key 'alt-d' };
    wait_screen_change { send_key 'alt-e' };
    type_string '/tmp';
    wait_screen_change { send_key 'alt-p' };
    wait_screen_change { send_key 'spc' };
    assert_screen 'yast2_apparmor_configuration_manage_existing_profiles_edit_add_directory_permissions_read';
    wait_screen_change { send_key 'down' };
    wait_screen_change { send_key 'spc' };
    assert_screen 'yast2_apparmor_configuration_manage_existing_profiles_edit_add_directory_permissions_write';
    wait_screen_change { send_key 'alt-o' };
    send_key 'alt-d';

    # confirm to save changes to the profile
    assert_screen 'yast2_apparmor_configuration_manage_existing_profiles_edit_file_changed';
    send_key 'alt-y';
    # add assert_screen here to check the page of edit profile and workaround the problem
    # with previous page got showed up for a very short timere the following
    assert_screen 'yast2_apparmor_configuration_manage_existing_profiles_edit';

    # close now AppArmor configuration
    send_key 'alt-n';
    wait_serial("yast2-apparmor-status-0", 200) || die "'yast2 apparmor' didn't finish";

    # part 3: manually add profile
    # prepare a new profile at first and check that the new file has been copied
    assert_script_run("cp /etc/apparmor.d/sbin.syslogd /new_profile");

    # start apparmor configuration again
    script_run("yast2 apparmor; echo yast2-apparmor-status-\$? > /dev/$serialdev", 0);
    assert_screen 'yast2_apparmor';
    wait_screen_change { send_key 'down' };
    wait_screen_change { send_key 'down' };
    send_key 'ret';
    assert_screen 'yast2_apparmor_configuration_add_profile';
    wait_screen_change { send_key 'alt-f' };
    for (1 .. 30) { send_key 'backspace'; }
    type_string '/new_profile';
    wait_screen_change { send_key 'alt-o' };

    # check profile dialog after new profile created and add a new rule to it
    assert_screen 'yast2_apparmor_configuration_profile_dialog';
    send_key 'alt-a';
    wait_screen_change { send_key 'alt-r' };
    wait_screen_change { send_key 'alt-s' };
    send_key 'alt-d';

    # confirm to save changes to profile and finish test
    assert_screen 'yast2_apparmor_configuration_manage_existing_profiles_edit_file_changed_again';
    send_key 'alt-y';
    wait_serial("yast2-apparmor-status-0", 200) || die "'yast2 apparmor' didn't finish";

}
1;

# vim: set sw=4 et:
