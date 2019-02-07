# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for Proposal Settings
# Dialog that appears after pressing an appropriate button on Suggested
# Partitioning Page.

# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Installation::Partitioner::Libstorage::ProposalSettingsDialog;
use strict;
use warnings FATAL => 'all';
use testapi;
use parent 'Installation::AbstractPage';

use constant {
    PROPOSAL_SETTINGS_DIALOG => 'inst-partition-radio-buttons'
};

sub select_encrypted_lvm_based_proposal_radiobutton {
    assert_screen(PROPOSAL_SETTINGS_DIALOG);
    send_key('alt-e');
}

sub select_lvm_based_proposal_radiobutton {
    assert_screen(PROPOSAL_SETTINGS_DIALOG);
    send_key('alt-l');
}

sub press_ok {
    assert_screen(PROPOSAL_SETTINGS_DIALOG);
    send_key('alt-o');
}

1;
