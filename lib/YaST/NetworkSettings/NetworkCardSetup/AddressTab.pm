# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for Address Tab in YaST2
# lan module dialog.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package YaST::NetworkSettings::NetworkCardSetup::AddressTab;
use strict;
use warnings;
use testapi;
use parent 'YaST::NetworkSettings::NetworkCardSetup::NetworkCardSetupWizard';

use constant {
    ADDRESS_TAB => 'yast2_lan_address_tab_selected'
};

sub select_dynamic_address {
    assert_screen(ADDRESS_TAB);
    send_key('alt-y');
}

sub select_no_link_and_ip_setup {
    assert_screen(ADDRESS_TAB);
    send_key('alt-k');
}

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(ADDRESS_TAB);
}

1;
