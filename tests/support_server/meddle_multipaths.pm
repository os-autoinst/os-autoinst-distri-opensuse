# Copyright (C) 2019 SUSE Linux GmbH
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

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
        mutex_wait("client_pkginstall_start", $jobid_client);
        assert_script_run("/usr/local/bin/multipath_flaky_luns.sh", 30);
        $meddler_pid = script_output("/bin/cat \"$meddler_pidfile\"", 30);
        record_info("Meddling", "Client system disk: LUN meddling started. PID: $meddler_pid");

        # Keep going until client reports that it is through package
        # installation and is about to reboot (see await_install.pm)
        mutex_wait("client_pkginstall_done", $jobid_client);

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
