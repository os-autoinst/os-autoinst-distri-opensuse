# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Address Tab in
# YaST2 lan module dialog, when VLAN is selected to be configured. The Tab
# contains all the same elements as the common Address Tab, but with some
# additional elements that are specific for VLAN.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::NetworkSettings::NetworkCardSetup::VLANAddressTab;
use strict;
use warnings;
use testapi;
use parent 'YaST::NetworkSettings::NetworkCardSetup::AddressTab';

use constant {
    ADDRESS_TAB => 'yast2_lan_address_tab_selected',
    VLAN_ID_WARNING => 'yast2_lan_vlan_id_warning'
};

sub fill_in_vlan_id {
    my ($self, $vlan_id) = @_;
    assert_screen(ADDRESS_TAB);
    send_key 'alt-v';
    send_key 'tab';
    wait_screen_change { type_string($vlan_id) };
}

sub decline_vlan_id_warning {
    assert_screen(VLAN_ID_WARNING);
    send_key 'alt-n';
}

1;
