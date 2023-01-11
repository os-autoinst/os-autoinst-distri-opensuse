# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for General Tab in YaST2
# lan module dialog.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

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
