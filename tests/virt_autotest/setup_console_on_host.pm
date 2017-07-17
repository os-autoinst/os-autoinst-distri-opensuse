# Summary: setup_console_on_host: Re-set serial port and update serial info to kernel option.
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

