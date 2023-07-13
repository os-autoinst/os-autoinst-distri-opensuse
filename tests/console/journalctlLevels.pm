# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: systemd util-linux-systemd
# Summary: Test to check that the logs with the custom error level are inserted
# in the journal
# Maintainer: Ivan Lausuch <ilausuch@suse.de>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use strict;
use warnings;

sub run {
    select_serial_terminal;

    record_info("INFO", "Logs all level0 severity types");
    assert_script_run "wget --quiet " . data_url('journalctl_levels/test.sh') . " -O test.sh";
    assert_script_run "chmod +x test.sh";

    my @levels = ("emerg", "alert", "crit", "warning", "notice", "info", "debug");

    foreach my $level (@levels)
    {
        assert_script_run "./test.sh $level";
    }
}

1;
