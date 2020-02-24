# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: run InfiniBand test suite hpc-testing
#
# Maintainer: Michael Moese <mmoese@suse.de>,

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;


sub run {
    if (get_required_var('IBTEST_ROLE') eq 'IBTEST_MASTER') {
        barrier_create('IBTEST_SETUP', 2);
        barrier_create('IBTEST_BEGIN', 2);
        barrier_create('IBTEST_DONE',  2);
    }

}

1;
