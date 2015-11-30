use base "consoletest";
use strict;
use testapi;

sub run() {
    become_root;

    my $snapfile = '/root/snapfile';

    my $snapbf = script_output "snapper create -p -d 'before undochange test'";
    script_run "date > $snapfile";
    my $snapaf = script_output "snapper create -p -d 'after undochange test'";

    # Delete snapfile
    script_run "snapper undochange $snapbf..$snapaf $snapfile";
    script_run "test -f $snapfile || echo \"snap-ba-ok\" > /dev/$serialdev";
    wait_serial("snap-ba-ok", 10) || die "Snapper undochange $snapbf..$snapaf failed";

    # Restore snapfile
    script_run "snapper undochange $snapaf..$snapbf $snapfile";
    script_run "test -f $snapfile && echo \"snap-ab-ok\" > /dev/$serialdev";
    wait_serial("snap-ab-ok", 10) || die "Snapper undochange $snapaf..$snapbf failed";

    assert_screen 'snapper_undochange', 3;

    script_run('exit');
}

sub test_flags() {
    return {important => 1};
}

1;
