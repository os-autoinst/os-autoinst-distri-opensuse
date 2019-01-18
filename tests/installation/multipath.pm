# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Enable multipath test
#    Signed-off-by: Dinar Valeev <dvaleev@suse.com>
# Maintainer: Dinar Valeev <dvaleev@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;

sub run {
    assert_screen "enable-multipath";
    send_key "alt-y";
}

sub test_flags {
    return {fatal => 1};
}

1;
