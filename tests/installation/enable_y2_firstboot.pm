# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Enable YaST2 Firstboot module - Desktop workstation configuration utility
# Doc: https://en.opensuse.org/YaST_Firstboot
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use utils qw(zypper_call clear_console);
use scheduler 'get_test_suite_data';

sub run {
    my $test_data = get_test_suite_data();
    my $base_path = "yast2/firstboot/";
    select_console 'root-console';
    zypper_call "in yast2-firstboot";
    assert_script_run 'touch /var/lib/YaST2/reconfig_system';
    # Use default files from package if no custom file was specified
    if ($test_data->{custom_control_file}) {
        assert_script_run 'wget ' . data_url($base_path . $test_data->{custom_control_file}) . ' -O /etc/YaST2/firstboot.xml';
        assert_script_run 'wget ' . data_url($base_path . $test_data->{sysconfig_firstboot}) . ' -O /etc/sysconfig/firstboot';
        assert_script_run 'mkdir /usr/share/firstboot/custom';
        assert_script_run 'wget ' . data_url($base_path . $_) . " -O /usr/share/firstboot/custom/$_" for qw(welcome.txt license.txt finish.txt);
    }
    clear_console;
}

1;
