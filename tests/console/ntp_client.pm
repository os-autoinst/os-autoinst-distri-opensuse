# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: chrony ntp
# Summary: Check for NTP clients
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle is_jeos);

sub run {
    select_serial_terminal;

    assert_script_run 'timedatectl';
    # check if pool file exists
    assert_script_run 'test -f /etc/chrony.d/pool.conf', fail_message => 'chrony-pool package is missing';

    if (is_sle() && !is_jeos) {
        systemctl 'enable chronyd';
        systemctl 'start chronyd';
        # chronyd can shift the number of used sources, especially after startup
        # in order to avoid a transient error *503 No such source* try to list sources until
        # chronyc returns non empty table
        # more info: https://bugzilla.suse.com/show_bug.cgi?id=1179022#c1
        my $inc = 0;
        while (scalar(split(/\n/, script_output('chronyc sources', proceed_on_failure => 1)) <= 3) && $inc < 10) {
            sleep(++$inc);
        }
    }
    # ensure that ntpd is neither installed nor enabled nor active
    systemctl 'is-active ntpd', expect_false => 1;
    systemctl 'is-enabled ntpd', expect_false => 1;
    die 'ntp should not be installed by default as we are using chrony' unless script_run('rpm -q ntp');

    # ensure that systemd-timesyncd is neither enabled nor active
    systemctl 'is-active systemd-timesyncd', expect_false => 1;
    systemctl 'is-enabled systemd-timesyncd', expect_false => 1;

    # ensure that chronyd is running
    systemctl 'is-enabled chronyd';
    systemctl 'is-active chronyd';
    systemctl 'status chronyd';
    # ensure and wait until time is actually synced before checking status
    # otherwise we could get a transient *503 No such source* on listing sources
    assert_script_run 'chronyc makestep';
    assert_script_run 'chronyc waitsync 120 0.5', 1210;
    assert_script_run 'chronyc sources';
    assert_script_run 'chronyc tracking';
    assert_script_run 'chronyc tracking';
    assert_script_run 'chronyc activity';
}

sub post_checks {
    assert_script_run 'chronyc sourcestats -a';
    assert_script_run 'chronyc serverstats';
    assert_script_run 'chronyc ntpdata';
    assert_script_run 'chronyc tracking';
    assert_script_run 'chronyc activity';
}

sub post_run_hook {
    post_checks;
}

sub post_fail_hook {
    post_checks;
    shift->SUPER::post_fail_hook;
}

1;
