# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: snapper
# Summary: Test for the snapshots created during upgrade
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

# fate#317900: Create snapshot before starting Upgrade

sub run {
    select_console 'root-console';

    my $waittime = 200 * get_var('TIMEOUT_SCALE', 1);

    # 'snapper list' will cost a lots of time to finish if btrfs-balance.sh was triggered
    # To make it faster, we'd check if snapper have disable-used-space option.
    # This is a workaround for bsc#1167353.
    record_info('workaround for bsc#1167353');
    script_run("(snapper --help | grep -q -- --disable-used-space && snapper list --disable-used-space || snapper list) | tee /dev/$serialdev", 0);
    # Check if the snapshot called 'before update' is there
    wait_serial('pre\s*(\|[^|]*){4,}\s*\|\s*number\s*\|\s*before (update|online migration)\s*\|\s*important=yes', $waittime)
      || die 'upgrade snapshots test failed';

    script_run("(snapper --help | grep -q -- --disable-used-space && snapper list --disable-used-space || snapper list) | tee /dev/$serialdev", 0);
    # Check if the snapshot called 'after update' is there
    wait_serial('post\s*(\|[^|]*){4,}\s*\|\s*number\s*\|\s*after (update|online migration)\s*\|\s*important=yes', $waittime)
      || die 'upgrade snapshots test failed';
}

1;
