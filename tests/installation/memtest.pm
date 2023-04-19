# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Simple memtest
# Maintainer: QE LSG <qa-team@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use bootloader_setup qw(ensure_shim_import select_bootmenu_more);

sub run {
    my $self = shift;
    ensure_shim_import;
    select_bootmenu_more('inst-onmemtest', 1);
    send_key 'f1' if (check_screen 'memtest-Fail-Safe-Mode', 10);
    assert_screen('pass-complete', 1000);
}

sub test_flags {
    return {fatal => 1};
}

1;
