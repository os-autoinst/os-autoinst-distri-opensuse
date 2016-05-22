# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package qam;

use strict;

use base "Exporter";
use Exporter;

use testapi;
use utils;

our @EXPORT = qw/capture_state/;

sub capture_state {
    my ($state, $y2logs) = @_;
    if ($y2logs) {    #save y2logs if needed
        assert_script_run "save_y2logs /tmp/y2logs_$state.tar.bz2";
        upload_logs "/tmp/y2logs_$state.tar.bz2";
        save_screenshot();
    }
    #upload ip status
    script_run("ip a | tee /tmp/ip_a_$state.log");
    upload_logs("/tmp/ip_a_$state.log");
    save_screenshot();
    script_run("ip r | tee /tmp/ip_r_$state.log");
    upload_logs("/tmp/ip_r_$state.log");
    save_screenshot();
    #upload dmesg
    script_run("dmesg > /tmp/dmesg_$state.log");
    upload_logs("/tmp/dmesg_$state.log");
    #upload journal
    script_run("journalctl -b > /tmp/journal_$state.log");
    upload_logs("/tmp/journal_$state.log");
}

1;
