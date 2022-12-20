# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Use qa_test_multipath to test multipath over iscsi
# - Install open-iscsi qa_test_multipath
# - Start iscsid and multipathd services
# - Set default variables for iscsi iqn and target
# - Configure test suite with proper iscsi iqn, target and wwid
# - Run "/usr/share/qa/qaset/qaset reset"
# - Run "/usr/share/qa/qaset/run/kernel-all-run.openqa"

# If ISCSI_MULTIPATH_FLAKY is set, modifications of the two I/O-intensive
# qa_test_multipath tests are run which leave the disabling/re-enabling
# of multipaths to the iSCSI server.

# Maintainer: Petr Cervinka <pcervinka@suse.com>, Klaus G. Wagner <kgw@suse.com>

use base 'qa_run';
use strict;
use warnings;
use lockapi;
use testapi;
use mmapi;
use utils;
use iscsi;

# FIXME: The status queries for qaset (pkg qa_testset_automation) in
# the subsequent two subs are rather awkward "unofficial" workarounds:
# the current qaset API does not seem to offer such queries.
#
# A request to implement API commands like, e.g.,
#
#     /usr/share/qa/qaset/qaset status		# clean/running/stopped/done
#     /usr/share/qa/qaset/qaset waitstop	# wait until status is "stopped"
#     /usr/share/qa/qaset/qaset waitdone	# wait until status is "done"
#
# is under way.
#
sub qaset_waitdone {
    # qaset has been observed to create file /var/log/qaset/control/DONE
    # as soon as
    # -  no testsuite run is in progress anymore _and_
    # -  there is no testsuite waiting for execution anymore
    #    (file /var/log/qaset/control/NEXT_RUN)
    #
    my ($timeout) = @_;
    assert_script_run(
        "until [ -f /var/log/qaset/control/DONE ]; do sleep 5; done",
        timeout => $timeout,
        fail_message => "qaset failed to announce overall completion within $timeout s");
}

# Invocation: qaset_waitstop(testname => $testname, timeout => $timeout [,prewait => $prewait]);
#
sub qaset_waitstop {
    #
    # FIXME: This sub is particularly awkward due to the need for $prewait.
    # Observed: the following qaset behavior:
    #
    # qaset creates file /var/log/qaset/control/SYSTEM_DIRTY as soon
    # as no testsuite run is in progress anymore (In contrast to
    # DONE further testsuites-to-execute may be left waiting, like
    # after a qaset stop).
    #
    # If some testsuite is left waiting for execution (file NEXT_RUN),
    # starting another qaset run will delete an existing file SYSTEM_DIRTY:
    # WARNING: but it has been observed to do so only after a delay of a few
    # (FIXME: how many?) seconds. It is thus unsafe to start polling for
    # SYSTEM_DIRTY immediately after such a restart. Hence $prewait.
    #
    my %args = @_;
    my $testname = $args{testname};
    my $timeout = $args{timeout};
    my $prewait = $args{prewait} // 15;    # 15 is guessed to be enough :-/
    sleep $prewait if $prewait > 0;
    assert_script_run(
        "until [ -f /var/log/qaset/control/SYSTEM_DIRTY ]; do sleep 5; done",
        timeout => $timeout,
        fail_message => "$testname: qaset run failed to complete in $timeout s");
}

sub start_testrun {
    my $self = shift;

    # the mandatory parallel supportserver job which provides the
    # multipathed test device.
    my $jobid_server = get_parents();
    $jobid_server = $jobid_server->[0];
    # needed if 'ISCSI_MULTIPATH_FLAKY' is set
    my $count = 1;
    # qa_test_multipath RPM: when deployed for testsuites sw_multipath_s_aa
    # resp. sw_multipath_s_ap, scripts active_active.sh, resp.,
    # active_passive.sh configure a runtime of 180 s each.
    # An openQA timeout of 360 s should therefore be plenty.
    my $tc_timeout = 360;

    zypper_call("in open-iscsi qa_test_multipath");

    systemctl 'start iscsid';
    systemctl 'start multipathd';

    # Set default variables for iscsi iqn and target
    my $iqn = get_var("ISCSI_IQN", "iqn.2016-02.de.openqa");
    my $target = get_var("ISCSI_TARGET", "10.0.2.1");

    # Connect to iscsi server and obtain wwid for multipath configuration
    iscsi_discovery $target;
    iscsi_login $iqn, $target;
    my $times = 10;
    ($times-- && sleep 1) while (script_run('multipathd -k"show multipaths status" | grep active') == 1 && $times);
    die 'multipath not ready even after waiting 10s' unless $times;
    my $wwid = script_output("multipathd -k\"show multipaths status\" | grep active | awk {'print \$1\'}");
    iscsi_logout $iqn, $target;

    # Configure test suite with proper iscsi iqn and target
    assert_script_run("sed -i '/^TARGET_DISK=.*/c\\TARGET_DISK=\"$iqn\"' /usr/share/qa/qa_test_multipath/data/vars");
    assert_script_run("sed -i '/^TARGET=.*/c\\TARGET=\"$target\"' /usr/share/qa/qa_test_multipath/data/vars");
    assert_script_run("cat /usr/share/qa/qa_test_multipath/data/vars");

    # Configure wwid in configuration files for each test
    my @config_files = qw(active_active active_passive path_checker_dio path_checker_tur);
    foreach my $config_file (@config_files) {
        assert_script_run "sed -i '/wwid .*/c\\wwid $wwid' /usr/share/qa/qa_test_multipath/data/$config_file";
        assert_script_run("cat /usr/share/qa/qa_test_multipath/data/$config_file");
    }

    $self->qaset_config();
    # workaround dashboard query https://sd.suse.com/servicedesk/customer/portal/1/SD-62274
    assert_script_run('rm /usr/share/qa/qaset/libs/msg_queue.sh');
    assert_script_run("/usr/share/qa/qaset/qaset reset");

    if (get_var('ISCSI_MULTIPATH_FLAKY')) {
        # The complication in this case is that the server must "tidy up"
        # (restore all damaged multipaths) after the completion of each
        # single testcase. Therefore
        #
        # -  client and supportserver need to keep communicating accordingly,
        #
        # -  each time a testcase is finished the client must take time out
        #    from the qaset-controlled run for the sake of this tidy-up.
        #
        # Associated supportserver module: tests/support_server/flaky_mp_iscsi.pm

        # iSCSI server and multipath export ready for action?
        mutex_wait("flakyserver_tidied_up$count", $jobid_server);
    }

    assert_script_run("/usr/share/qa/qaset/run/kernel-all-run.openqa");

    if (get_var('ISCSI_MULTIPATH_FLAKY')) {
        # The above qaset command above returns _immediately_ (the
        # actual testrun takes place in detached screen sessions).
        # So no significant time is lost before the ensuing communication.

        # "supportserver: feel free to start meddling with the LUNs of the
        # provided multipathed test device"
        mutex_create "flakyserver_testcase_started$count";
        record_info("start$count", "Mutex \"flakyserver_testcase_started$count\" created.");

        # Wait a bit to make sure the first testsuite is under way, then
        # set a stop mark for qaset (a kind of suspend, actually), to become
        # effective after this testsuite (testcase sw_multipath_s_aa).
        sleep 10;
        assert_script_run("/usr/share/qa/qaset/qaset stop");
        qaset_waitstop(testname => "sw_multipath_s_aa", timeout => $tc_timeout, prewait => 0);

        # "supportserver: My first testcase is through. Please tidy up"
        mutex_create "flakyserver_testcase_done$count";
        record_info("done$count", "Mutex \"flakyserver_testcase_done$count\" created");
        $count++;
        # wait for server's ACK before taking up the next testsuite
        mutex_wait("flakyserver_tidied_up$count", $jobid_server);
        # The multipathed test device is now supposedly tidy again.

        # Release stop file /var/log/qaset/control/STOP
        script_run("/usr/share/qa/qaset/qaset resume");
        # Only the following re-invocation actually resumes with the next
        # one-testcase testsuite: sw_multipath_s_ap (found in file NEXT_RUN)
        assert_script_run("/usr/share/qa/qaset/run/kernel-all-run.openqa");
        # Notify the supportserver that it's time to re-commence LUN meddling...
        mutex_create "flakyserver_testcase_started$count";
        record_info("start$count", "Mutex \"flakyserver_testcase_started$count\" created.");

        # It is a qaset restart: better leave parameter $prewait at its default.
        # (see the function comment above).
        # Test expected to run for about 180 s.
        #
        qaset_waitstop(testname => "sw_multipath_s_ap", timeout => $tc_timeout);

        # "supportserver: please tidy up once more"
        mutex_create "flakyserver_testcase_done$count";
        record_info("done$count", "Mutex \"flakyserver_testcase_done$count\" created");
        $count++;
        mutex_wait("flakyserver_tidied_up$count", $jobid_server);
        #
        # _Note:_  For a potential future of more than two testsuites
        # the above procedure could be iterated.
        # TODO: write a proper loop for this.

        # For now it's just the above two testcases: we are done
        # The final wrap-up follows:

        # After the second testcase finished, the overall completion is
        # expected to be announced immediately.
        qaset_waitdone(30);
        # "supportserver: module flaky_mp_iscsi.pm may now terminate"
        mutex_create "flakyserver_testcases_done_all";
        record_info("done_all", "Mutex \"flakyserver_testcases_done_all\" created");
        # wait for server's final ACK, then terminate
        mutex_wait("flakyserver_ACK_done", $jobid_server);
    }
}

# (supposedly overrides  sub test_run_list() in qa_run.pm)
sub test_run_list {
    if (get_var('ISCSI_MULTIPATH_FLAKY')) {
        return qw(_reboot_off sw_multipath_s_aa sw_multipath_s_ap);
    }
    else {
        return qw(_reboot_off sw_multipath);
    }
}

1;
