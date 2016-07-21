# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base 'consoletest';
use strict;
use testapi;
use utils;

# fate#317973: Create initial snapshot at the end of installation/update
# bnc#935923: Cleanup and consistent naming for snapshots made during installation
#
# Checks that the initial snapshot is created, its strategy is set to "number"
# and user data is set to "important=yes"

sub run() {
    select_console 'root-console';

    script_run("snapper list | tee /dev/$serialdev", 0);
    # Check if the corresponding snapshot is there
    my ($snapshot_name, $snapshot_type);

    if (is_jeos) {
        $snapshot_name = 'Initial Status';
        $snapshot_type = 'single';
    }
    elsif (get_var('AUTOUPGRADE')) {
        $snapshot_name = 'before update';
        $snapshot_type = 'pre';
    }
    elsif (get_var('ONLINE_MIGRATION')) {
        $snapshot_name = 'before online migration';
        $snapshot_type = 'pre';
    }
    else {
        $snapshot_name = 'after installation';
        $snapshot_type = 'single';
    }

    my $pattern = $snapshot_type . '\s*(\|[^|]*){4}\s*\|\s*number\s*\|\s*' . $snapshot_name . '\s*\|\s*important=yes';

    wait_serial($pattern, 20) || die "$snapshot_name snapshot test failed";
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:
