# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles common grub screen actions.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::Pom::GrubMenuBasePageBug1230121;
use strict;
use warnings;
use parent 'Yam::Agama::Pom::GrubMenuBasePage';
use testapi;

sub select_first_entry {
    record_soft_failure("bsc#1230121 - Agama-live SLES-16 Alpha installation. Unable to login after installation");
    wait_screen_change { send_key('e') };
    send_key_until_needlematch('linux-line-selected', 'down', 26);
    wait_screen_change { send_key('end') };
    wait_still_screen(1);
    send_key('backspace');
    type_string('0');
    wait_still_screen(1);
    save_screenshot;
    send_key('ctrl-x');
}

1;
