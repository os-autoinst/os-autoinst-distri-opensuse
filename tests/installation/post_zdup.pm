# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Prepare system for reboot after zdup upgrade
# Maintainer: QE LSG <qa-team@suse.de>

use base "installbasetest";
use testapi;
use utils;
use power_action_utils 'power_action';
use Utils::Backends 'is_pvm';
use x11utils 'close_gui_terminal';

sub run {
    clear_console;

    zypper_call "lr -d";
    # Remove the --force when this is fixed: https://bugzilla.redhat.com/1075131
    # Because of poo#32458 Hyper-V can't switch from VT to X11 and has to use
    # whatever the default in the image is.
    systemctl('set-default --force graphical.target');

    if (get_var('ZDUP_IN_X')) {
        # For ZDUP_IN_X, let a DE specific module take care of the reboot.
        close_gui_terminal;
    } else {
        # switch to root-console (in case we are in X)
        select_console 'root-console';
        power_action('reboot', keepconsole => 1, textmode => 1);
        reconnect_mgmt_console if is_pvm;
    }
}

1;
