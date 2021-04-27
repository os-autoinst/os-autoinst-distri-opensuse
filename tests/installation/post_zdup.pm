# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Prepare system for reboot after zdup upgrade
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base "installbasetest";
use strict;
use warnings;
use testapi;
use utils;
use power_action_utils 'power_action';
use Utils::Backends 'is_pvm';

sub run {
    clear_console;

    zypper_call "lr -d";
    # Remove the --force when this is fixed: https://bugzilla.redhat.com/1075131
    # Because of poo#32458 Hyper-V can't switch from VT to X11 and has to use
    # whatever the default in the image is.
    systemctl('set-default --force graphical.target');

    # switch to root-console (in case we are in X)
    select_console 'root-console';
    power_action('reboot', keepconsole => 1, textmode => 1);
    reconnect_mgmt_console if is_pvm;
}

1;
