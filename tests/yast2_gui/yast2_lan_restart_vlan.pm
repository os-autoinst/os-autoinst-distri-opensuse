# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The test verifies that network is not restarted if no changes were
# made to the configuration of VLAN device but "Ok" button was pressed in
# Network Settings. Related tasks: fate#318787 poo#11450
#
# Pre-conditions:
# Create VLAN device.
#
# Test:
# 1. Open Network Settings Dialog;
# 2. Press "Edit" button to view the configuration of VLAN device;
# 3. Proceed through the Edit configuration wizard, but do not change anything;
# 4. Save the changes by pressing "Ok" button in Network Settings dialog;
# 5. Verify the Network is not restarted.
#
# Post-condition:
# Delete the VLAN device.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use y2lan_restart_common qw(initialize_y2lan open_network_settings check_network_status wait_for_xterm_to_be_visible clear_journal_log close_xterm);

my $network_settings;

sub pre_run_hook {
    initialize_y2lan;
    open_network_settings;
    $network_settings = $testapi::distri->get_network_settings();
    $network_settings->add_vlan_device();
    $network_settings->save_changes();
    wait_for_xterm_to_be_visible();
}

sub run {
    record_info('VLAN', 'Verify network is not restarted after saving VLAN device settings without changes.');
    open_network_settings;
    $network_settings->view_vlan_device_without_editing();
    $network_settings->save_changes();
    wait_for_xterm_to_be_visible();
    clear_journal_log();
    check_network_status('no_restart_or_reload', 'vlan');
}

sub post_run_hook {
    open_network_settings;
    $network_settings->delete_vlan_device();
    # return ethernet card settings to the default ones
    $network_settings->select_dynamic_address_for_ethernet();
    $network_settings->save_changes();
    wait_for_xterm_to_be_visible();
    close_xterm();
}

1;
