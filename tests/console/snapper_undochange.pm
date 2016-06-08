# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use strict;
use testapi;
use utils;

sub run() {
    select_console 'root-console';

    my $snapfile = '/root/snapfile';

    my $snapbf = script_output "snapper create -p -d 'before undochange test'";
    script_run "date > $snapfile";
    my $snapaf = script_output "snapper create -p -d 'after undochange test'";

    # Delete snapfile
    script_run "snapper undochange $snapbf..$snapaf $snapfile";
    script_run("test -f $snapfile || echo \"snap-ba-ok\" > /dev/$serialdev", 0);
    wait_serial("snap-ba-ok", 10) || die "Snapper undochange $snapbf..$snapaf failed";

    # Restore snapfile
    script_run "snapper undochange $snapaf..$snapbf $snapfile";
    assert_script_run "test -f $snapfile", 10;

    assert_screen_with_soft_timeout('snapper_undochange', soft_timeout => 3);
}

sub test_flags() {
    return {important => 1};
}

1;
