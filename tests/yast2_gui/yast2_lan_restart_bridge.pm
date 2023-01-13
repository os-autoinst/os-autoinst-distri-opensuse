# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-network
# Summary: The test verifies that network is not restarted if no changes were
# made to the configuration of Bridged device but "Ok" button was pressed in
# Network Settings. Related tasks: fate#318787 poo#11450
#
# Pre-conditions:
# Create Bridged device.
#
# Test:
# 1. Open Network Settings Dialog;
# 2. Press "Edit" button to view the configuration of Bridged device;
# 3. Proceed through the Edit configuration wizard, but do not change anything;
# 4. Save the changes by pressing "Ok" button in Network Settings dialog;
# 5. Verify the Network is not restarted.
#
# Post-condition:
# Delete the Bridged device.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_module_guitest';
use strict;
use warnings;
use testapi;
use y2lan_restart_common qw(initialize_y2lan open_network_settings check_network_status wait_for_xterm_to_be_visible clear_journal_log close_xterm);
use YuiRestClient;

my $network_settings;

sub pre_run_hook {
    my ($self) = @_;
    initialize_y2lan;
    open_network_settings;
    $network_settings = $testapi::distri->get_network_settings();
    $network_settings->add_bridged_device();
    $network_settings->save_changes();
    # After network settings were changed, DHCP may assign another IP address (e.g. on xen-hvm).
    # Init IP address again, so that libyui will be able to communicate with the YaST module.
    YuiRestClient::set_host(YuiRestClient::init_host());
    select_console('x11', await_console => 0);
    wait_for_xterm_to_be_visible();
    clear_journal_log();
    $self->SUPER::pre_run_hook;
}

sub run {
    record_info('bridge', 'Verify network is not restarted after saving bridged device settings without changes.');
    open_network_settings;
    $network_settings->view_bridged_device_without_editing();
    $network_settings->cancel_changes();
    $network_settings->accept_all_changes_will_be_lost();
    wait_for_xterm_to_be_visible();
    check_network_status('no_restart_or_reload', 'bridge');
}

sub post_run_hook {
    open_network_settings;
    $network_settings->delete_bridged_device();
    # return ethernet card settings to the default ones
    $network_settings->select_dynamic_address_for_ethernet();
    $network_settings->save_changes();
    wait_for_xterm_to_be_visible();
    close_xterm();
}

1;
