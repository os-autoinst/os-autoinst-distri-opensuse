# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: RESCUECD test
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "rescuecdstep";
use strict;
use warnings;
use testapi;

sub run {
    assert_screen "rescuecd-desktop", 120;

    # Mount and show the local hard disk content
    assert_and_dclick "hd-volume";
    assert_screen "hd-mounted", 6;

    x11_start_program('xterm');
    script_run "cd `cat /proc/self/mounts | grep /dev/vda2 | cut -d' ' -f2`";
    script_sudo "sh -c 'cat etc/SUSE-brand > /dev/$serialdev'";
    wait_serial("VERSION = 13.1", 2) || die "Not SUSE-brand found";
}

1;

