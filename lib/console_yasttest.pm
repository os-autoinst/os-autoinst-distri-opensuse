# Base for YaST tests.  Switches to text console 2 and uploady y2logs

package console_yasttest;
use base "opensusebasetest";
use strict;

use testapi;

sub post_fail_hook() {
    my $self = shift;

    select_console 'root-console';
    save_screenshot;

    script_run "dmesg > /dev/$serialdev";
    my $fn = '/tmp/y2logs.tar.bz2';
    # only upload if save_y2log succeeded
    if (!script_run "save_y2logs $fn") {
        upload_logs $fn;
    }
    else {
        select_console 'log-console';
        # there is a severe problem, e.g. could be bsc#985850 or bsc#990384 so
        # save more, let's hope there is enough memory for intermediate
        # storage
        # TODO just assuming that '/dev/vda2' is the root device here, does
        # not work for LVM setup and others but we want to debug non-LVM first
        # /dev/root is not recognized as btrfs device
        $fn = '/dev/shm/vda2_brfs_debug_tree';
        assert_script_run "btrfs-debug-tree /dev/vda2 &> $fn";
        upload_logs $fn;
    }
    save_screenshot;
}

sub post_run_hook {
    my ($self) = @_;

    $self->clear_and_verify_console;
}

# Executes the command line tests from a yast repository (in master or in the
# given optional branch) using prove
sub run_yast_cli_test {
    my ($self, $packname) = @_;
    my $PACKDIR = '/usr/src/packages';

    assert_script_run "zypper -n in $packname";
    assert_script_run "zypper -n si $packname";
    assert_script_run "rpmbuild -bp $PACKDIR/SPECS/$packname.spec";
    script_run "pushd $PACKDIR/BUILD/$packname-*";

    # Run 'prove' only if there is a directory called t
    script_run("if [ -d t ]; then echo -n 'run'; else echo -n 'skip'; fi > /dev/$serialdev", 0);
    my $action = wait_serial(['run', 'skip'], 10);
    if ($action eq 'run') {
        assert_script_run 'prove';
    }

    script_run 'popd';

    # Should we cleanup after?
    #script_run "rm -rf $packname-*";
}

1;
# vim: set sw=4 et:
