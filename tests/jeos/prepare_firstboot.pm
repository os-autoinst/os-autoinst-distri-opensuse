# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Enable jeos-firstboot as required by openQA testsuite
# Maintainer: Guillaume GARDET <guillaume@opensuse.org>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use utils 'zypper_call';

sub run {
    my ($self) = @_;

    my $default_password          = 'linux';
    my $distripassword            = $testapi::password;
    my $reboot_for_jeos_firstboot = 1;

    my $is_generalhw_via_ssh = check_var('BACKEND', 'generalhw') && !defined(get_var('GENERAL_HW_VNC_IP'));

    if ($is_generalhw_via_ssh) {
        # Run jeos-firstboot manually and do not reboot as we use SSH
        $reboot_for_jeos_firstboot = 0;

        # Handle default credentials for ssh login
        $testapi::password = $default_password;
        $self->select_serial_terminal;
    }
    else {
        # Login with default credentials (root:linux)
        assert_screen('linux-login', 300);
        type_string("root\n",              wait_still_screen => 5);
        type_string("$default_password\n", wait_still_screen => 5);
    }

    # Install and enable jeos-firstboot
    zypper_call('in jeos-firstboot');

    if ($is_generalhw_via_ssh) {
        # Do not set eth0 down as we are connected through ssh!
        assert_script_run("sed -i 's/ip link set down \"\$d\" #/if [ \"eth0\" != \"\$d\" ]; then ip link set down \"\$d\"; fi; #/' /usr/lib/jeos-firstboot");
    }
    # Remove current root password
    assert_script_run("sed -i 's/^root:[^:]*:/root:*:/' /etc/shadow", 600);

    # Restore expected password, to be used by jeos-firstboot
    $testapi::password = $distripassword;

    if ($reboot_for_jeos_firstboot) {
        # Ensure YaST2-Firstboot is disabled, as we use jeos-firstboot in openQA
        assert_script_run("systemctl disable YaST2-Firstboot");
        assert_script_run("systemctl enable jeos-firstboot");

        assert_script_run("touch /var/lib/YaST2/reconfig_system");

        type_string("reboot\n");
    }
    else {
        type_string("/usr/lib/jeos-firstboot\n");
    }

}

1;
