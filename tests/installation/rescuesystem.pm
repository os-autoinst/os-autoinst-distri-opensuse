# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Ensure rescue system can be booted into a shell prompt
# Maintainer: QE LSG <qa-team@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use bootloader_setup qw(ensure_shim_import select_bootmenu_more);
use Utils::Architectures 'is_aarch64';

sub run {
    my $self = shift;

    # We can't see inst-sys on Xen PV, bootloader_svirt
    # does the job to get us into rescue mode.
    unless (check_var('VIRSH_VMM_TYPE', 'linux')) {
        ensure_shim_import;
        select_bootmenu_more('inst-rescuesystem', 1);
    }

    # booting up on aarch64 takes longer and extend timeout to prevent failure, see poo#120513
    my $timeout = (is_aarch64) ? 200 : 120;
    assert_screen 'keyboardmap-list', $timeout;
    send_key "ret";

    # Login as root (no password)
    assert_screen "rescuesystem-login";
    enter_cmd "root";

    # Clean the screen
    sleep 1;
    enter_cmd "reset";
    assert_screen "rescuesystem-prompt";
}

sub test_flags {
    return {fatal => 1};
}

1;
