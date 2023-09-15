# SLE15 migration tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Fully patch the system before conducting migration and then reboot
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_desktop_installed is_upgrade);
use power_action_utils 'power_action';
use migration;

sub run {
    my ($self) = @_;

    select_console 'root-console';

    # Repeatedly call zypper patch until it returns something other than 103 (package manager updates)
    my $ret = 1;
    for (1 .. 3) {
        $ret = zypper_call("patch --with-interactive -l", exitcode => [0, 4, 102, 103], timeout => 6000);
        last if $ret != 103;
    }
    if (($ret == 4) && is_sle('>=12') && is_sle('<15')) {
        my $para = '';
        $para = '--force-resolution' if get_var('FORCE_DEPS');
        $ret = zypper_call("patch --with-interactive -l $para", exitcode => [0, 102], timeout => 6000);
        save_screenshot;
    }
    die "Zypper failed with $ret" if ($ret != 0 && $ret != 102);
    assert_script_run 'sync', 600;
    power_action('reboot', textmode => 1, keepconsole => 1);
    $self->wait_boot(textmode => !is_desktop_installed, bootloader_time => 500, ready_time => 600);
}

1;
