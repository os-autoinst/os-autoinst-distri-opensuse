# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Enable jeos-firstboot as required by openQA testsuite
# Maintainer: Guillaume GARDET <guillaume@opensuse.org>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use utils 'zypper_call';
use version_utils qw(is_leap is_sle);
use Utils::Backends;

sub run {
    my ($self) = @_;

    my $default_password = 'linux';
    my $distripassword = $testapi::password;
    my $reboot_for_jeos_firstboot = 1;

    my $is_generalhw_via_ssh = is_generalhw && !defined(get_var('GENERAL_HW_VNC_IP'));

    if (get_var('GENERAL_HW_VIDEO_STREAM_URL')) {
        # capture boot sequence and wait for login prompt on raw HDMI output
        record_info 'HDMI begin', 'Test HDMI and USB keyboard';
        select_console('sut');
        assert_screen('linux-login', 200);
        if (get_var('GENERAL_HW_KEYBOARD_URL')) {
            enter_cmd("root", wait_still_screen => 5);
            enter_cmd(is_sle() ? "$testapi::password" : "$default_password", wait_still_screen => 5);
            assert_screen('text-logged-in-root');
        }
        record_info 'HDMI end';
    }


    if ($is_generalhw_via_ssh) {
        # Run jeos-firstboot manually and do not reboot as we use SSH
        $reboot_for_jeos_firstboot = 0;

        if (!is_sle()) {
            # Handle default credentials for ssh login
            # On SLE we use an image preprocessed by openQA where the default
            # $testapi::password was set
            $testapi::password = $default_password;
        }
        # 'root-ssh' console will wait for SUT to be reachable from ssh
        select_console('root-ssh');
    }
    else {
        # Login with default credentials (root:linux)
        assert_screen('linux-login', 300);
        enter_cmd("root", wait_still_screen => 5);
        enter_cmd("$default_password", wait_still_screen => 5);
    }

    # Install jeos-firstboot, when needed
    zypper_call('in jeos-firstboot') if is_leap;

    if ($is_generalhw_via_ssh) {
        # Do not set network down as we are connected through ssh!
        my $filetoedit = '/usr/share/jeos-firstboot/modules/network-modules/wicked';
        if (is_leap('<=15.2')) {
            $filetoedit = '/usr/lib/jeos-firstboot';
        }
        elsif (is_sle('<15-sp4') or is_leap('<15.4')) {
            $filetoedit = '/usr/share/jeos-firstboot/jeos-firstboot-dialogs';
        }
        assert_script_run("sed -i 's/ip link set down /# ip link set down/g' $filetoedit");
    }
    # Remove current root password
    assert_script_run("sed -i 's/^root:[^:]*:/root:*:/' /etc/shadow", 600);

    # Restore expected password, to be used by jeos-firstboot
    $testapi::password = $distripassword;

    if ($reboot_for_jeos_firstboot) {
        # Ensure YaST2-Firstboot is disabled, and enable jeos-firstboot in openQA
        assert_script_run("systemctl disable YaST2-Firstboot") if is_leap('<15.2');
        assert_script_run("systemctl enable jeos-firstboot");

        # When YaST2-Firstboot is not installed, /var/lib/YaST2 does not exist, so create it
        assert_script_run("mkdir -p /var/lib/YaST2") if !is_leap('<15.2');
        # Trigger *-firstboot at next boot
        assert_script_run("touch /var/lib/YaST2/reconfig_system");

        enter_cmd("reboot");
    }
    else {
        enter_cmd(is_leap('<=15.2') ? "/usr/lib/jeos-firstboot\n" : "jeos-firstboot");
    }
}

1;
