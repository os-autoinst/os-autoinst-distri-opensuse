# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: New test to take the first disk
#    Otherwise the partitioning proposal will use a free disk, which makes
#    rebooting a game of chance on real hardware
# Maintainer: Stephan Kulow <coolo@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use version_utils 'is_storage_ng';
use partition_setup 'take_first_disk';

sub run {
    take_first_disk;
}

1;
