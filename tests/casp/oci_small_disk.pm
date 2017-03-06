# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Installation should not start if disk is too small
# Maintainer: Martin Kravec <mkravec@suse.com>

use strict;
use base "y2logsstep";
use testapi;

sub run() {
    # Replace by assert_screen when error message is implemented by YaST
    die "bsc#1019652 - Don't allow too small partitions";
}

1;
# vim: set sw=4 et:
