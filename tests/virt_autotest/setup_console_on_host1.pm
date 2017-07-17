# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: setup_console_on_host1: Re-set serial port and update serial info to kernel option.
# Maintainer: alice <xlai@suse.com>

use strict;
use warnings;
use base "proxymode";
use testapi;
use virt_utils;

sub run {
    resetup_console();
}

sub test_flags {
    return {fatal => 1};
}

1;

