# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Login to the openQA webui
# Maintainer: Dominik Heidler <dheidler@suse.de>

use strict;
use warnings;
use base "x11test";
use testapi;

sub run {
    assert_and_click 'openqa-login';
    assert_screen 'openqa-logged-in';
}

sub test_flags {
    return {fatal => 1};
}

sub post_run_hook {
    # do not assert generic desktop
}

1;
