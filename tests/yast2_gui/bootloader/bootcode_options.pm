# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Open bootloader gui, verify default setting in ui, change
# some settings and verify that they have been applied.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;
use scheduler 'get_test_suite_data';
use YaST::Module;
use cfg_files_utils;
use x11utils 'start_root_shell_in_xterm';
use y2lan_restart_common 'close_xterm';

my $bootloader;
my $test_data;

sub verify_current_options {
    validate_cfg_file($test_data->{bootcode_applied_params}->{verify_current_options});
    verify_boot_code();    # Validating beforehand as we cannot press cancel see boo#1186132
    YaST::Module::run_actions {
        my %current_settings = $bootloader->get_current_settings();
        compare_settings({expected => $test_data->{bootcode_options}, current => \%current_settings});
    } module => 'bootloader', ui => 'qt';
    validate_cfg_file($test_data->{bootcode_applied_params}->{verify_current_options});
    verify_boot_code();
}

sub change_settings_then_verify {
    my ($args) = @_;
    my $action = $args->{action};
    YaST::Module::run_actions {
        record_info $action;
        $bootloader->$action();
    } module => 'bootloader', ui => 'qt';
    validate_cfg_file($test_data->{bootcode_applied_params}->{$action});    # verify changes in /etc/default/grub_installdevice
    verify_boot_code({device => $args->{device}, generic_boot_code => $args->{generic_boot_code}});
}

sub verify_boot_code {    # Check if boot code is installed, defaults to GRUB on MBR
    my ($args) = @_;
    my $device = $args->{device} ? $args->{device} : $test_data->{bootcode_device}->{default};
    if ($args->{generic_boot_code}) {
        assert_script_run("dd if=$device bs=512 count=1 | hexdump -C | grep -v GRUB 2>&1 >/dev/null");
        assert_script_run("dd if=$device bs=512 count=1 | hexdump -C | grep boot");
    } else {
        assert_script_run("dd if=$device bs=512 count=1 | hexdump -C | grep GRUB");
    }
}

sub run {
    $bootloader = $testapi::distri->get_bootloader_settings();
    $test_data = get_test_suite_data();
    start_root_shell_in_xterm();

    # Check that UI is initialized with expected default parameters
    verify_current_options();

    # If we chose to enable "generic boot code" and also "write to MBR", GRUB must still be installed on MBR as
    # it has priority over generic boot code.
    change_settings_then_verify({action => 'write_generic_to_mbr'});

    # Unselect write_to_mbr, verify that the GRUB is no longer on MBR but generic boot code is here instead,
    # as it was enabled in previous step.
    change_settings_then_verify({action => 'dont_write_to_mbr', generic_boot_code => 1});

    # Select "write to partition" and see if GRUB is installed on the partition.
    change_settings_then_verify({
            action => 'write_to_partition',
            device => $test_data->{bootcode_device}->{write_to_partition}});

    close_xterm();
}

1;
