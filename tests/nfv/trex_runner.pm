# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Trex traffic generator runner
#
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "opensusebasetest";
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Backends;
use strict;
use warnings;
use utils;
use lockapi;

sub run {
    my $self = shift;
    select_serial_terminal;

    my $trex_dir = "/tmp/trex-core";

    record_info("INFO", "Start TREX in background");
    script_run("cd /tmp/trex-core");
    enter_cmd("nohup bash /tmp/trex-core/t-rex-64 -i &") if (is_ipmi);

    record_info("INFO", "Wait for NFV tests to be completed. Waiting for Mutex NFV_TESTING_DONE");
    mutex_wait('NFV_TESTING_DONE');
}

sub test_flags {
    return {fatal => 1};
}

1;
