# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Last controller module test
# Maintainer: Martin Kravec <mkravec@suse.com>

use parent 'caasp_controller';

use strict;
use warnings;
use caasp 'unpause';
use mmapi 'wait_for_children';

sub run {
    # Allow cluster nodes to finish
    unpause 'CNTRL_FINISHED';
    # Wait until they export logs
    wait_for_children;
}

1;

