# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "opensusebasetest";
use strict;
use testapi;
use utils qw/wait_boot/;

sub run() {
    my $self = shift;

    # run rasdaemon
    assert_script_run "rasdaemon --record";

    # load kernel module
    assert_script_run "modprobe mce_amd_inj";

    # Inject some software errors
    script_run "echo 0x9c00410000080f2b > /sys/kernel/debug/mce-inject/status";
    script_run "echo d5a099a9 > /sys/kernel/debug/mce-inject/addr";
    script_run "echo 4 > /sys/kernel/debug/mce-inject/bank";
    script_run "echo 0xdead57ac1ba0babe > /sys/kernel/debug/mce-inject/misc";
    script_run "echo \"sw\" > /sys/kernel/debug/mce-inject/flags";

    # check the errors and pipe it to $serialdev
    assert_script_run "ras-mc-ctl --errors | tee /dev/$serialdev";
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
