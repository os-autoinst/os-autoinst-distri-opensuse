# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for Suggested
# Partitioning Page.

# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Installation::Partitioner::Libstorage::SuggestedPartitioningPage;

use strict;
use warnings FATAL => 'all';
use testapi;
use parent 'Installation::Partitioner::SuggestedPartitioningPage';

sub press_edit_proposal_settings_button {
    my ($self) = @_;
    assert_screen($self->SUGGESTED_PARTITIONING_PAGE);
    send_key('alt-d');
}

1;
