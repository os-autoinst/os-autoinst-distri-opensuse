# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for Address Tab in
# YaST2 lan module dialog, when VLAN is selected to be configured. The Tab
# contains all the same elements as the common Address Tab, but with some
# additional elements that are specific for VLAN.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package YaST::NetworkSettings::NetworkCardSetup::VLANAddressTab;
use strict;
use warnings;
use testapi;
use parent 'YaST::NetworkSettings::NetworkCardSetup::AddressTab';

use constant {
    ADDRESS_TAB => 'yast2_lan_address_tab_selected'
};

sub fill_in_vlan_id {
    my ($self, $vlan_id) = @_;
    assert_screen(ADDRESS_TAB);
    send_key 'alt-v';
    send_key 'tab';
    wait_screen_change { type_string($vlan_id) };
}

1;
