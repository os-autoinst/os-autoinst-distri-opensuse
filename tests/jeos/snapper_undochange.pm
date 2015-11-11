use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    my $snapfile = '/root/snapfile';

    my $snapbf = script_output "snapper create -p -d 'before undochange test'";
    script_run "date > $snapfile";
    my $snapaf = script_output "snapper create -p -d 'after undochange test'";

    script_run "snapper undochange $snapbf..$snapaf";
    script_run "test -f $snapfile || echo \"snap-ba-ok\" > /dev/$serialdev";
    wait_serial("snap-ba-ok", 10) || die "Snapper undochange $snapbf..$snapaf failed";

    script_run "snapper undochange $snapaf..$snapbf";
    script_run "test -f $snapfile && echo \"snap-ab-ok\" > /dev/$serialdev";
    wait_serial("snap-ab-ok", 10) || die "Snapper undochange $snapaf..$snapbf failed";

    assert_screen 'jeos-snapper_undochange', 3;
}

sub test_flags() {
    return {important => 1};
}

1;
