# SUSE's openQA tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-apparmor
# Summary: Check configuration of apparmor, add and delete apparmor profiles;
# Toggle Enable/Disable Apparmor;
# List active/loaded profile;
# Toggle 'Show all available profiles';
# Close interface and confirm systemd unit is still running;
# Reopen application and edit existing profile: Change permissions && save;
# Create a new profile for 'top' binary;
# Maintainer: Sergio R Lemke <slemke@suse.com>;

use strict;
use warnings;
use base "y2_module_consoletest";
use testapi;
use utils qw(zypper_call systemctl);
use version_utils qw(is_pre_15 is_sle is_opensuse is_leap);
use Utils::Logging 'save_and_upload_systemd_unit_log';

sub install_extra_packages_requested {
    if (check_screen 'yast2_apparmor_extra_packages_requested', 15) {
        send_key 'alt-i';
        wait_still_screen 5;
        save_screenshot;
    }
}

sub toggle_mode {
    wait_still_screen(3);
    if (is_pre_15()) {
        record_soft_failure 'bsc#1126289 - yast2_apparmor - cannot toggle first profile in the list';
        # try out with second element in the list
        send_key 'tab';
        wait_still_screen(2);
        send_key 'down';
        wait_still_screen(2);
    }
    send_key(is_pre_15() ? 'alt-t' : 'alt-c');
    # toggle takes some seconds:
    wait_still_screen(stilltime => 5);
    if (is_pre_15()) {
        send_key 'tab';
        wait_still_screen(2);
        send_key 'end';
    }
}

sub run {
    select_console 'root-console';

    # install yast2_apparmor package at first
    zypper_call 'in yast2-apparmor';

    # start apparmor configuration
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'apparmor');
    # assert that app was opened appeared
    #SLES <15 extra packages are needed after main window:
    if (is_pre_15()) {
        assert_screen 'yast2_apparmor';
        send_key 'ret';
        install_extra_packages_requested;
    } else {
        #SLES >=15 imediatelly asks for extra packages, not after main menu:
        install_extra_packages_requested;
        assert_screen 'yast2_apparmor', 60;
        send_key 'alt-l';
    }

    assert_screen([qw(yast2_apparmor_disabled yast2_apparmor_enabled)], 90);
    if (match_has_tag 'yast2_apparmor_disabled') {
        send_key 'alt-e';
        assert_screen 'yast2_apparmor_enabled';
    } else {
        #workaround needed for SLES > 12.4 to keep the test moving.
        #conditional wrapping  this products and catch if appears in another versions as well:
        #this entire else block can be removed once bsc#1129280 is fixed via maintenance channels.
        if (is_sle('>=12-SP4') || is_leap('>=15.0')) {
            send_key 'alt-e';
            sleep 3;
            send_key 'alt-e';
            record_info 'bsc#1129280', 'bsc#1129280 - Toggled "enable apparmor" to ensure systemd unit is started';
            assert_screen 'yast2_apparmor_enabled';
        }
    }

    # wait for the configure keyboard shortcut being active
    wait_still_screen(3);
    # part 1: open profile mode configuration and check toggle/show all profiles
    send_key(is_pre_15() ? 'alt-n' : 'alt-c');

    assert_screen([qw(yast2_apparmor_profile_mode_configuration yast2_apparmor_failed_to_change_bsc1058981 yast2_apparmor_profile_mode_configuration_PID_error)]);
    if (match_has_tag 'yast2_apparmor_failed_to_change_bsc1058981') {
        send_key 'alt-o';
        wait_still_screen(3);
        record_soft_failure 'bsc#1058981';
        send_key 'f9';
        wait_still_screen(3);
        return;
    } elsif (match_has_tag 'yast2_apparmor_profile_mode_configuration_PID_error') {
        record_soft_failure 'bsc#1132418 - addpid error';
        send_key 'ret';
        return;
    }

    #Show all profiles
    send_key(is_pre_15() ? 'alt-o' : 'alt-s');
    toggle_mode;
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
        toggle_mode;
        assert_screen 'yast2_apparmor_profile_mode_configuration_toggle';
    }
    wait_screen_change { send_key 'alt-b' } if is_pre_15();

    # close apparmor configuration
    send_key(is_pre_15() ? 'alt-d' : 'alt-f');

    #double check, in rare circumstances its needed to re-send the finish command.
    if (match_has_tag 'yast2_apparmor_profile_mode_configuration_toggle') {
        send_key 'alt-f';
    }

    # increase value for timeout to 200 seconds
    wait_serial("$module_name-0", 200) || die "'yast2 apparmor' didn't finish";
    systemctl 'show -p ActiveState apparmor.service | grep ActiveState=active';
    # currently not existing on sle15
    if (is_pre_15()) {
        # part 2: start apparmor configuration again
        $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'apparmor');
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
        # with previous page got showed up for a very short timer the following
        assert_screen 'yast2_apparmor_configuration_manage_existing_profiles_edit';

        # close now AppArmor configuration
        send_key 'alt-n';
        wait_serial("$module_name-0", 200) || die "'yast2 apparmor' didn't finish";

    }

    # part 3: manually add profile using system binary (see bsc#1144072).
    # start apparmor configuration again
    $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'apparmor');
    assert_screen 'yast2_apparmor';
    wait_screen_change { send_key 'down' };
    wait_screen_change { send_key 'down' };
    send_key 'ret';
    assert_screen 'yast2_apparmor_configuration_add_profile';
    wait_screen_change { send_key 'alt-f' };

    for (1 .. 15) { send_key 'backspace'; }

    if (is_pre_15) {
        enter_cmd "/usr/bin/top";
    } else {
        enter_cmd "top";
        send_key 'alt-o';
        assert_screen 'yast2_apparmor_profile_for_top_generated';
        send_key 'alt-f';
        #confirm profile generation
        assert_screen 'yast2_apparmor_profile_generated';
        send_key 'alt-o';
        #wait till app is closed
        wait_serial("$module_name-0", 200) || die "'yast2 apparmor' didn't finish";
        #cleaning the console
        enter_cmd "reset";
        return;
    }

    send_key 'alt-o';

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
    save_and_upload_systemd_unit_log('apparmor');
    $self->SUPER::post_fail_hook;
}

1;
