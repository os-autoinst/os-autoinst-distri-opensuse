# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Unlock the SUT from the support service
# Maintainer: Michael Moese <mmoese@suse.de>

use base 'baremetalbasetest';
use strict;
use warnings;


sub run {
    my $self = shift;
    $self->host_unlock();
}
