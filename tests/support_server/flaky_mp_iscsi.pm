# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: collaborate with tests/qa_automation/kernel_multipath.pm for a
#          multipath client robustness test. This supportserver module will
#          keep disturbing the iSCSI LUNs of the multipathed test device.
# Maintainer: Klaus G. Wagner <kgw@suse.com>

use strict;
use warnings;
use base 'basetest';
use lockapi;
use testapi;
use mmapi;
use iscsi;

sub run {
    my $self  = shift;
    my $count = 1;
    # See: data/supportserver/iscsi/multipath_flaky_luns.sh
    my $meddler_pidfile = "/tmp/multipath_flaky_luns.pid";
    my $meddler_pid;

    # This provides the job ID of the one parallel job (supposed to run
    # kernel_multipath.pm)
    # _NOTE_: the mutex_*() functions **need** this as second arg to work reliably.
    my $jobid_client = get_children();
    $jobid_client = (keys %$jobid_client)[0];

    my $testcase_in_progress = 0;
    my $done_all             = 0;
    my $client_says_proceed  = 0;
    # poll frequency in seconds :-/
    my $poll_client_says_proceed = 5;
    my $delay_meddling           = 10;

    while (1) {
        # check whether multipathed iSCSI target it is really tidied up, then
        mutex_create "flakyserver_tidied_up$count";
        record_info("tidy$count", "Mutex \"flakyserver_tidied_up$count\" created");
        #
        # Upon this the server supposedly will eventually receive
        # notice by the client via
        #     a) "flakyserver_testcase_started$count" or
        #     b) "flakyserver_testcases_done_all"
        # It is unknown which one, so we can't invoke mutex_wait() right away.
        # FIXME: Instead, we resort to polling (except at the very start). UGLY!
        # See os-autoinst-distri-opensuse/os-autoinst/lockapi.pm
        # for mutex_try_lock(). Its advantage: it does not block!
        #
        unless ($count == 1) {
            until ($client_says_proceed) {
                sleep $poll_client_says_proceed;
                $testcase_in_progress = mutex_try_lock("flakyserver_testcase_started$count", $jobid_client);
                $done_all             = mutex_try_lock('flakyserver_testcases_done_all',     $jobid_client);
                $client_says_proceed = $testcase_in_progress || $done_all;

                # DEBUG: provide an idea of timing
                record_info("Proceed?", "\$count =  $count: Received "
                      . ($client_says_proceed ? "\"Go ahead\"" : "no notice yet")
                      . " from client");
            }
            last if ($done_all);
            # The subsequent mutex_wait() is now just a formality: expected to succeed immediately.
        }
        mutex_wait("flakyserver_testcase_started$count", $jobid_client);
        # Test takes about 180 s. Wait a bit before starting to meddle with my LUNS
        sleep $delay_meddling;
        assert_script_run("/usr/local/bin/multipath_flaky_luns.sh", 30);
        $meddler_pid = script_output("/bin/cat \"$meddler_pidfile\"", 30);
        record_info("Meddling", "LUN meddling started: iteration $count (PID $meddler_pid)");

        mutex_wait("flakyserver_testcase_done$count", $jobid_client);
        # Client testcase run is done: terminate meddling (triggers tidy-up
        # of LUNs and $meddler_pidfile along the way)
        $client_says_proceed = 0;
        script_run("kill -INT $meddler_pid");
        record_info("SIGINT", "LUN meddling SIGINTed: iteration $count (PID $meddler_pid)");
        # FIXME: ugly polling :-/
        # wait for tidy-up action to complete ($meddler_pidfile will disappear)
        assert_script_run("until ! [ -e \"$meddler_pidfile\" ] ; do sleep 5; done", 90);
        # FIXME: then report (just for the record).
        script_run("/usr/local/bin/multipath_flaky_luns.sh -l", 30);
        $count++;
    }

    # Formality; expected to succeed immediately
    mutex_wait('flakyserver_testcases_done_all', $jobid_client);
    record_info("AllDone!", "Got mutex: flakyserver_testcases_done_all.");
    # Let the client know that it's now OK to terminate.
    mutex_create "flakyserver_ACK_done";
}

sub test_flags {
    return {fatal => 1};
}

1;
