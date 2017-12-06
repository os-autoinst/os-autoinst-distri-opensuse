# Base for YaST tests.  Switches to text console 2 and uploady y2logs

package console_yasttest;
use base "opensusebasetest";
use strict;

use testapi;

sub post_fail_hook {
    my $self = shift;

    select_console 'log-console';
    save_screenshot;

    script_run "dmesg > /dev/$serialdev";
    my $fn = '/tmp/y2logs.tar.bz2';
    # only upload if save_y2log succeeded
    if (!script_run "save_y2logs $fn") {
        upload_logs $fn;
    }
    else {
        # there is a severe problem, e.g. could be bsc#985850 or bsc#990384 so
        # save more, let's hope there is enough memory for intermediate
        # storage
        record_soft_failure 'bsc#990384';
        # CAUTION just assuming that '/dev/vda2' is the root device here, does
        # not work for LVM setup and others but we want to debug non-LVM first
        # /dev/root is not recognized as btrfs device
        $fn = '/dev/shm/vda2_brfs_debug_tree';
        assert_script_run "btrfs-debug-tree /dev/vda2 &> $fn";
        upload_logs $fn;
    }
    save_screenshot;
    $self->investigate_yast2_failure();
}

sub post_run_hook {
    my ($self) = @_;

    $self->clear_and_verify_console;
}

1;
# vim: set sw=4 et:
