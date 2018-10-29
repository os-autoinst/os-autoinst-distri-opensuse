# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Trex traffic generator runner
#
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "opensusebasetest";
use testapi;
use strict;
use utils;
use lockapi;

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    my $trex_dir = "/tmp/trex-core";

    record_info("INFO", "Start TREX in background");
    script_run("cd /tmp/trex-core");
    type_string("nohup bash /tmp/trex-core/t-rex-64 -i &\n") if (check_var('BACKEND', 'ipmi'));

    record_info("INFO", "Wait for NFV tests to be completed. Waiting for Mutex NFV_TESTING_DONE");
    mutex_wait('NFV_TESTING_DONE');
}

sub test_flags {
    return {fatal => 1};
}

1;
