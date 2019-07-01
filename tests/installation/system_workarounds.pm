# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Special handling to get workarounds applied ASAP
# Maintainer: Guillaume GARDET <guillaume@opensuse.org>

use strict;
use warnings;
use testapi;
use base 'opensusebasetest';

sub run {
    select_console('root-console');

    # Add your workarounds here
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
