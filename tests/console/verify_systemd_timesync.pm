# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify that systemd timer is used for time synchronization.
#          - Check if yast-timer configuration file exists and contains expected values.
#          - Check configured time synchronization server address.
#          - Check the message logs for "One time synchronization" occurrence.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;
use scheduler 'get_test_suite_data';
use Test::Assert ':all';

sub run {
    my $test_data = get_test_suite_data();
    select_console 'root-console';

    record_info("Check configuration", "Check if file /etc/systemd/system/yast-timesync.timer exists and has expected configuration.");
    assert_script_run('ls /etc/systemd/system/yast-timesync.timer');
    my $conf_file = script_output("cat /etc/systemd/system/yast-timesync.timer");
    $conf_file =~ /OnUnitActiveSec=(?<interval>\S+)min/;
    my $expected_interval = $test_data->{profile}->{'ntp-client'}->{ntp_sync};
    assert_equals($expected_interval, $+{interval}, "The interval in yast-timesync configuration file is not the expected one.");

    record_info("Check server", "Check if the configured time synchronization server is the expected one.");
    my $expected_server = $test_data->{profile}->{'ntp-client'}->{ntp_servers}->{ntp_server}->{address};
    my $chrony_conf = script_output("cat /etc/chrony.conf");
    $chrony_conf =~ /(\R|^)pool\s(?<server>\S+)/;
    assert_equals($expected_server, $+{server});

    record_info("Check sync", "Check if the use of systemd timers can be spotted in the journal logs as expected.");
    # The first "One time synchronization" is not happening immediately after boot. In order to make sure that first sync
    # has already happened before checking the logs, the following loop will check the logs repeatedly until logs are found
    # or uptime minutes are more that OnBootSec+1 ( +1 due to timers inaccuracy ).
    $conf_file =~ /OnBootSec=(?<onbootsec>\S+)min/;
    my $uptime;
    my $not_synced = 1;
    {
        do {
            $not_synced = script_run("journalctl -u yast-timesync | grep -E \"Started\|Finished One time sync configured by YaST\"");
            last unless ($not_synced);
            $uptime = script_output("uptime | cut -c19,20");
            script_run("echo \"Waiting 10 seconds before rechecking logs for One time synchronization\"");
            sleep 10;
        } while ($uptime <= ($+{onbootsec} + 1));
    }
    die "One time synchronization was not spotted in the journal logs as expected" if $not_synced;
}

1;
