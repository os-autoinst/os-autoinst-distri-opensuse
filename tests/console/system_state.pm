# SUSE's openQA tests
#
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary:  Export the existing status of running tasks and system load
# for future reference
# Maintainer: Zaoliang Luo <zluo@suse.de>

use base "consoletest";
use testapi;
use utils;
use strict;

sub run {
    my $self = @_;
    $self->select_serial_terminal;
    script_run "ps axf > /tmp/psaxf.log";
    script_run "cat /proc/loadavg > /tmp/loadavg_consoletest_setup.txt";
}

1;
