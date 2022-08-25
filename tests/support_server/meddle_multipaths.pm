# Copyright 2019 SUSE Linux GmbH
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: A test for the supportserver in the role of (iSCSI)
# system disk provider for the SUT.
#
# During initial installation, while the client is installing its
# packages: run a disk access robustness test by meddling with
# the LUNs of this system disk (the client will see non-fatal
# fails of the corresponding multipaths).
#
# Expected effect: no harm. The client installation is supposed
# to proceed completely undisturbed (multipath robustness).
#
# Maintainer: Klaus G. Wagner <kgw@suse.com>

use strict;
use warnings;
use base 'basetest';
use lockapi;
use testapi;    # sub autoinst_url()
use mmapi;

sub run {
    my $self = shift;

    if (!get_var('SUPPORT_SERVER')) {
        $self->result('ok');
        return 1;
    }

    if (get_var('SUPPORT_SERVER_TEST_INSTDISK_MULTIPATH')) {
        my $jobid_client = get_children();
        # the SUT job
        $jobid_client = (keys %$jobid_client)[0] or die "supportserver: no client job found";
        # reference: multipath_flaky_luns.sh
        my $meddler_pidfile = "/tmp/multipath_flaky_luns.pid";
        my $meddler_pid;

        # Wait until client reports that, after it properly got its system
        # disk, heavy I/O is now about to begin (see start_install.pm).
        assert_script_run("/usr/local/bin/multipath_flaky_luns.sh", 30);
        $meddler_pid = script_output("/bin/cat \"$meddler_pidfile\"", 30);
        record_info("Meddling", "Client system disk: LUN meddling started. PID: $meddler_pid");

        # Restore the multipaths and report (cf. support_server/flaky_mp_iscsi.pm)
        script_run("kill -INT $meddler_pid");
        record_info("SIGINT", "LUN meddling SIGINTed. PID: $meddler_pid");
        assert_script_run("until ! [ -e \"$meddler_pidfile\" ] ; do sleep 5; done", 90);
        script_run("/usr/local/bin/multipath_flaky_luns.sh -l", 30);

        # Notify client that that all paths are now restored
        # (reference: reboot_after_installation.pm)
        mutex_create("multipathed_iscsi_export_clean", $jobid_client);
        record_info("MP clean", "Mutex \"multipathed_iscsi_export_clean\" set");
    }
    else {
        record_info("No action", "SUPPORT_SERVER_TEST_INSTDISK_MULTIPATH is not set");
    }
    $self->result('ok');
}


sub test_flags {
    return {fatal => 1};
}

1;
