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

package Installation::Partitioner::NewPartitionSizePage;
use strict;
use warnings;
use testapi;
use parent 'Installation::WizardPage';

use constant {
    NEW_PARTITION_SIZE_PAGE => 'partition-size'
};

sub enter_size {
    my ($self, $size) = @_;
    assert_screen(NEW_PARTITION_SIZE_PAGE);
    send_key('alt-s');
    type_string($size);
}

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(NEW_PARTITION_SIZE_PAGE);
}

1;
