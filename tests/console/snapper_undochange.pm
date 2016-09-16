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

sub run() {
    select_console 'root-console';

    my $snapfile = '/root/snapfile';

    my $snapbf = script_output "snapper create -p -d 'before undochange test'", 90;
    script_run "date > $snapfile";
    my $snapaf = script_output "snapper create -p -d 'after undochange test'", 90;

    # Delete snapfile
    script_run "snapper undochange $snapbf..$snapaf $snapfile", 90;
    script_run("test -f $snapfile || echo \"snap-ba-ok\" > /dev/$serialdev", 0);
    wait_serial("snap-ba-ok", 30) || die "Snapper undochange $snapbf..$snapaf failed";

    # Restore snapfile
    script_run "snapper undochange $snapaf..$snapbf $snapfile", 90;
    assert_script_run("test -f $snapfile", timeout => 10, fail_message => "File $snapfile could not be found");

    assert_screen 'snapper_undochange';
}

sub test_flags() {
    return {important => 1};
}

1;
