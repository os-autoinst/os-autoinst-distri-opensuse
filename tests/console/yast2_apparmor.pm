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
use base "consoletest";
use testapi;



sub run() {

    select_console 'root-console';

    # install yast2_apparmor package at first
    assert_script_run("/usr/bin/zypper -n -q in yast2-apparmor");

    # start apparmor configuration
    script_run("yast2 apparmor; echo yast2-apparmor-status-\$? > /dev/$serialdev", 0);

    # check Apparmor Configuration is opened
    assert_screen 'yast2_apparmor';
    wait_still_screen(2);
    wait_screen_change { send_key 'ret' };
    if (!check_screen 'yast2_apparmor_enabled') {
        wait_screen_change { send_key 'alt-e' };
    }
    else {
        # No need to enable apparmor here because it is enabled by default. This got changed again.
    }
    assert_screen 'yast2_apparmor_enabled';
    # part 1: open profile mode configuration and check toggle/show all profiles
    send_key 'alt-n';
    assert_screen 'yast2_apparmor_profile_mode_configuration';
    send_key 'alt-o';
    wait_still_screen(1);
    assert_screen 'yast2_apparmor_profile_mode_configuration_show_all';
    wait_still_screen(1);
    send_key 'tab';
    wait_still_screen(1);
    send_key 'down';
    wait_still_screen(1);
    send_key 'alt-t';
    assert_screen 'yast2_apparmor_profile_mode_configuration_toggle';
    wait_still_screen(1);
    send_key 'alt-b';
    wait_still_screen(1);

    # close apparmor configuration
    send_key 'alt-d';
    wait_still_screen(1);
    assert_script_run("systemctl show -p ActiveState apparmor.service | grep ActiveState=active");

    # part 2: start apparmor configuration again
    script_run("yast2 apparmor; echo yast2-apparmor-status-\$? > /dev/$serialdev", 0);
    assert_screen 'yast2_apparmor';
    send_key 'down';
    assert_screen 'yast2_apparmor_configuration_manage_existing_profiles';
    send_key 'ret';
    assert_screen 'yast2_apparmor_configuration_manage_existing_profiles_edit_add';
    send_key 'alt-i';
    wait_still_screen(1);
    send_key 'alt-a';
    wait_still_screen(1);
    send_key 'alt-f';
    wait_still_screen(1);
    assert_screen 'yast2_apparmor_configuration_manage_existing_profiles_edit_add_file';
    send_key 'ret';
    wait_still_screen(1);
    send_key 'alt-e';
    wait_still_screen(1);
    type_string 'I_added_this_profile';
    wait_still_screen(1);
    send_key 'alt-p';
    wait_still_screen(1);
    send_key 'down';
    send_key 'up';
    send_key 'spc';
    send_key 'down';
    send_key 'spc';

    # confirm with cancel
    send_key 'alt-c';
    wait_still_screen(1);

    # now add a directory with permission for read and write
    send_key 'alt-a';
    wait_still_screen(1);
    send_key 'alt-d';
    wait_still_screen(1);
    send_key 'alt-b';
    wait_still_screen(1);
    send_key 'alt-c';
    wait_still_screen(1);
    send_key 'alt-e';
    wait_still_screen(1);
    type_string '/tmp';
    wait_still_screen(1);
    send_key 'alt-p';
    wait_still_screen(1);
    send_key 'down';
    send_key 'up';
    send_key 'spc';
    send_key 'down';
    send_key 'spc';
    send_key 'alt-o';
    wait_still_screen(1);
    send_key 'alt-d';

    # confirm to save changes to the profile
    assert_screen 'yast2_apparmor_configuration_manage_existing_profiles_edit_file_changed';
    send_key 'alt-y';

    # close now AppArmor configuration
    wait_still_screen(3);
    send_key 'alt-n';
    wait_still_screen(2);

    # part 3: manually add profile
    # prepare a new profile at first
    script_run("cp /etc/apparmor.d/sbin.syslogd /new_profile");

    #start apparmor configuration again
    script_run("yast2 apparmor; echo yast2-apparmor-status-\$? > /dev/$serialdev", 0);
    assert_screen 'yast2_apparmor';
    send_key 'down';
    send_key 'down';
    send_key 'ret';
    assert_screen 'yast2_apparmor_configuration_add_profile';
    send_key 'alt-f';
    for (1 .. 30) { send_key 'backspace'; }
    type_string '/new_profile';
    wait_still_screen(1);
    send_key 'alt-o';
    wait_still_screen(2);

    # Add entry for new profile
    send_key 'alt-a';
    send_key 'alt-r';
    send_key 'alt-s';
    send_key 'alt-d';

    # confirm to save changes to profile
    assert_screen 'yast2_apparmor_configuration_manage_existing_profiles_edit_file_changed_again';
    send_key 'alt-y';

    # finish test
    wait_serial("yast2-apparmor-status-0", 60) || die "'yast2 apparmor' didn't finish";


}
1;

# vim: set sw=4 et:
