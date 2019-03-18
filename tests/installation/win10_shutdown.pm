# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Split Windows 10 test
# Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use base "installbasetest";
use strict;
use warnings;

use testapi;

sub run {
    send_key 'alt-f4';
    assert_screen 'windows-shutdown';
    send_key 'ret';    # press ok to shutdown the os
    assert_shutdown;
}

1;
