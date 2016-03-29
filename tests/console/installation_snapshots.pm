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
    # Check if the snapshot called 'after installation' is there
    my $pattern = 'single\s*(\|[^|]*){4}\s*\|\s*number\s*\|\s*after installation\s*\|\s*important=yes';
    $pattern = 'single\s*(\|[^|]*){4}\s*\|\s*number\s*\|\s*Factory status\s*\|\s*important=yes' if is_jeos;
    $pattern = 'pre\s*(\|[^|]*){4}\s*\|\s*number\s*\|\s*before update\s*\|\s*important=yes' if get_var('AUTOUPGRADE');
    wait_serial($pattern, 5) || die 'installation snapshot test failed';
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:
