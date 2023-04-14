# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify mediacheck function on the DVD
# Maintainer: Max Lin <mlin@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use bootloader_setup qw(ensure_shim_import select_bootmenu_more);

sub run {
    my $self = shift;
    my $iterations = 0;
    ensure_shim_import;
    select_bootmenu_more('inst-onmediacheck', 1);

    while ($iterations++ < 3) {
        assert_screen [qw(mediacheck-select-device mediacheck-ok mediacheck-checksum-wrong)], 300;
        send_key "ret";
        if (match_has_tag('mediacheck-select-device')) {
            next;
        }
        if (match_has_tag('mediacheck-checksum-wrong')) {
            die "Checksum reported as wrong";
        }
        last;
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
