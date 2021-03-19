# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Test scenario which configures Kdump with a YaST module
# and checks configuration without rebooting the system.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base "y2_module_consoletest";
use strict;
use warnings;

use cfg_files_utils 'validate_cfg_file';
use kdump_utils;
use registration;
use scheduler 'get_test_suite_data';
use testapi;
use utils;

sub run {
    select_console('root-console');

    # install kdump by adding additional modules
    add_suseconnect_product('sle-module-desktop-applications');
    add_suseconnect_product('sle-module-development-tools');
    zypper_call('in yast2-kdump');

    # Kdump configuration with YaST module
    kdump_utils::activate_kdump;

    # check service (without restarting)
    systemctl('is-enabled kdump');

    validate_cfg_file(get_test_suite_data()->{config_files});

    # delete additional modules
    remove_suseconnect_product('sle-module-development-tools');
    remove_suseconnect_product('sle-module-desktop-applications');

    # info for next tests
    record_info('Notice', 'If next modules scheduled after this one will require ' .
          'a reboot, take into account that kdump options will take effect.');
}

1;
