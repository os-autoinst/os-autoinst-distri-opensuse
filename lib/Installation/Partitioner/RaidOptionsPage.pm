# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: TODO
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Installation::Partitioner::RaidOptionsPage;
use strict;
use warnings;
use testapi;
use parent 'Installation::WizardPage';

use constant {
    RAID_OPTIONS_PAGE => 'partitioning_raid-add_raid-chunk_size'
};

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(RAID_OPTIONS_PAGE);
}

1;
