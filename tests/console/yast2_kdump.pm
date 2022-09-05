# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

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
use version_utils 'is_sle';

sub run {
    select_console('root-console');

    # install kdump by adding additional modules
    add_suseconnect_product('sle-module-desktop-applications');
    add_suseconnect_product('sle-module-development-tools');
    zypper_call('in kdump') if is_sle('15-SP5+');
    zypper_call('in yast2-kdump');

    # Kdump configuration with YaST module
    kdump_utils::activate_kdump(increase_kdump_memory => 0);

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
