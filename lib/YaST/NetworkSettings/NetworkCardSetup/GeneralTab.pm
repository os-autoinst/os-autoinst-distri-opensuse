# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for General Tab in YaST2
# lan module dialog.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package YaST::NetworkSettings::NetworkCardSetup::GeneralTab;
use strict;
use warnings;
use testapi;
use parent 'YaST::NetworkSettings::NetworkCardSetup::NetworkCardSetupWizard';

use constant {
    NETWORK_CARD_SETUP => 'yast2_lan_network_card_setup'
};

sub select_tab {
    assert_screen(NETWORK_CARD_SETUP);
    send_key('alt-g');
}

1;
