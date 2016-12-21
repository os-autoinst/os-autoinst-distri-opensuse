# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify mediacheck function on the DVD
# Maintainer: Max Lin <mlin@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use utils 'ensure_shim_import';
use bootloader_setup 'pre_bootmenu_setup';

sub run {
    my $self = shift;

    # handle mediacheck for usb boot if non-uefi
    if (!get_var("UEFI")) {
        return if pre_bootmenu_setup == 3;
    }

    ensure_shim_import;
    $self->select_bootmenu_option('inst-onmediacheck', 1);

    # the timeout is insane - but some old DVDs took almost forever, could
    # recheck with all current one and lower again
    assert_screen [qw(mediacheck-ok mediacheck-checksum-wrong)], 3600;
    send_key "ret";
    if (match_has_tag('mediacheck-checksum-wrong')) {
        die "Checksum reported as wrong";
    }
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
