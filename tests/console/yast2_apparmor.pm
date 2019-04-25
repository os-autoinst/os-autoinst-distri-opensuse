# SUSE's openQA tests
#
# Copyright (c) 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: check configuration of apparmor, add and delete apparmor profiles
# Maintainer: Zaoliang Luo <zluo@suse.de>

use strict;
use warnings;
use base "console_yasttest";
use testapi;
use utils 'systemctl';
use version_utils 'is_pre_15';

sub run {
    select_console 'root-console';

    # install yast2_apparmor package at first
    assert_script_run("/usr/bin/zypper -n -q in yast2-apparmor");

    # start apparmor configuration
    my $module_name = y2logsstep::yast2_console_exec(yast2_module => 'apparmor');
    # check Apparmor Configuration is opened
    assert_screen 'yast2_apparmor';
    send_key 'ret';

    assert_screen [qw(yast2_apparmor_disabled yast2_apparmor_enabled)];
    if (match_has_tag 'yast2_apparmor_disabled') {
        send_key 'alt-e';
    }
    assert_screen 'yast2_apparmor_enabled';

    # part 1: open profile mode configuration and check toggle/show all profiles
    send_key(is_pre_15() ? 'alt-n' : 'alt-c');

    assert_screen([qw(yast2_apparmor_profile_mode_configuration yast2_apparmor_failed_to_change_bsc1058981)]);
    if (match_has_tag 'yast2_apparmor_failed_to_change_bsc1058981') {
        send_key 'alt-o';
        wait_still_screen(3);
        record_soft_failure 'bsc#1058981';
        send_key 'f9';
        wait_still_screen(3);
        return;
    }

    #Show all configs
    send_key(is_pre_15() ? 'alt-o' : 'alt-s');
    assert_screen 'yast2_apparmor_profile_mode_configuration_show_all';
    wait_screen_change { send_key 'tab' };                              # focus on first element in the list
    wait_screen_change { send_key(is_pre_15() ? 'alt-t' : 'alt-c') };
    assert_screen [qw(
          yast2_apparmor_profile_mode_configuration_toggle
          yast2_apparmor_profile_mode_configuration_show_all
          yast2_apparmor_profile_mode_not_visible
          )];
    if (match_has_tag 'yast2_apparmor_profile_mode_not_visible') {
        record_soft_failure 'bsc#1127714 - yast2_apparmor does not display mode column when profile name is too long';
        send_key_until_needlematch 'yast2_apparmor_profile_mode_configuration_show_all', 'tab';
        wait_screen_change { send_key 'tab' };
        send_key_until_needlematch('yast2_apparmor_profile_mode_configuration_toggle', 'right');
    }
    elsif (match_has_tag 'yast2_apparmor_profile_mode_configuration_show_all') {
        record_soft_failure 'bsc#1126289 - yast2_apparmor - cannot toggle first profile in the list';
        # try out with second element in the list
        wait_screen_change { send_key 'tab' };
        wait_screen_change { send_key 'down' };
        save_screenshot;
        send_key(is_pre_15() ? 'alt-t' : 'alt-c');
        if (is_pre_15()) {
            wait_screen_change { send_key 'tab' };
            wait_screen_change { send_key 'end' };    # we need to search for recent toggled element at the of the list
        }
        assert_screen 'yast2_apparmor_profile_mode_configuration_toggle';
    }
    wait_screen_change { send_key 'alt-b' } if is_pre_15();

    # close apparmor configuration
    send_key(is_pre_15() ? 'alt-d' : 'alt-f');
    # increase value for timeout to 200 seconds
    wait_serial("$module_name-0", 200) || die "'yast2 apparmor' didn't finish";
    systemctl 'show -p ActiveState apparmor.service | grep ActiveState=active';
    # currently not existing on sle15
    if (is_pre_15()) {
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
        assert_screen 'yast2_apparmor_file_permissions_read';
        wait_screen_change { send_key 'down' };
        wait_screen_change { send_key 'spc' };
        assert_screen 'yast2_apparmor_file_permissions_write';

        # confirm with cancel
        wait_screen_change { send_key 'alt-c' };

        # now add a directory with permission for read and write
        wait_screen_change { send_key 'alt-a' };
        wait_screen_change { send_key 'alt-d' };
        wait_screen_change { send_key 'alt-e' };
        type_string '/tmp';
        wait_screen_change { send_key 'alt-p' };
        wait_screen_change { send_key 'spc' };
        assert_screen 'yast2_apparmor_dir_permissions_read';
        wait_screen_change { send_key 'down' };
        wait_screen_change { send_key 'spc' };
        assert_screen 'yast2_apparmor_dir_permissions_write';
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
        wait_serial("$module_name-0", 200) || die "'yast2 apparmor' didn't finish";

    }

    # part 3: manually add profile
    # prepare a new profile at first and check that the new file has been copied
    assert_script_run("cp /etc/apparmor.d/sbin.syslogd /new_profile");

    # start apparmor configuration again
    $module_name = y2logsstep::yast2_console_exec(yast2_module => 'apparmor');
    assert_screen 'yast2_apparmor';
    wait_screen_change { send_key 'down' };
    wait_screen_change { send_key 'down' };
    send_key 'ret';
    assert_screen 'yast2_apparmor_configuration_add_profile';
    wait_screen_change { send_key 'alt-f' };
    for (1 .. 30) { send_key 'backspace'; }
    type_string '/new_profile';
    send_key 'alt-o';
    send_key 'alt-o';

    if (!is_pre_15()) {
        send_key 'alt-o';
        # cleaning the console
        type_string "reset\n";
        return;
    }

    # check profile dialog after new profile created and add a new rule to it
    assert_screen 'yast2_apparmor_configuration_profile_dialog';
    send_key 'alt-a';
    wait_screen_change { send_key 'alt-r' };
    wait_screen_change { send_key 'alt-s' };
    send_key 'alt-d';

    # confirm to save changes to profile and finish test
    assert_screen 'yast2_apparmor_configuration_manage_existing_profiles_edit_file_changed_again';
    send_key 'alt-y';
    wait_serial("$module_name-0", 200) || die "'yast2 apparmor' didn't finish";
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'log-console';
    $self->save_and_upload_systemd_unit_log('apparmor');
    $self->SUPER::post_fail_hook;
}

1;
