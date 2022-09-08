# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: add addon to SLES via SCC
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base qw(y2_installbase y2_module_guitest);
use strict;
use warnings;
use testapi;
use registration;
use version_utils qw(is_sle is_leap);
use x11utils 'turn_off_gnome_screensaver';
use YaST::Module;
use utils;

sub test_setup {
    select_console "x11";
    x11_start_program('xterm');
    turn_off_gnome_screensaver;
}

sub run {
    my $self = shift;
    test_setup;
    YaST::Module::open(module => 'scc', ui => 'qt');
    save_screenshot;

    $testapi::distri->get_registration()->register_via_scc({
            email => get_var('SCC_EMAIL'),
            reg_code => get_var('SCC_REGCODE')});
    save_screenshot;

    my @scc_addons = split ',', get_var('SCC_ADDONS');
    $testapi::distri->get_module_registration()->register_extension_and_modules([@scc_addons]);
    save_screenshot;

    # No libyui-rest-api for advance software selection
    assert_screen("yast_scc-pkgtoinstall", 100);
    wait_screen_change {
        send_key 'alt-a';
    };
    assert_screen("yast_scc-installation-summary", 100);

    $testapi::distri->get_module_registration_installation_report()->press_finish();
    save_screenshot;

    assert_screen("generic-desktop", 60);
    # Check that repos actually work
    $self->select_serial_terminal;
    zypper_call 'refresh';
    zypper_call 'repos --details';
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    $self->save_upload_y2logs;
    verify_scc;
    investigate_log_empty_license;
}

sub test_flags {
    # add milestone flag to save setup in lastgood VM snapshot
    return {fatal => 1, milestone => 1};
}

1;
