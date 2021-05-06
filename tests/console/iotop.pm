# SUSE's openQA tests
#
# Copyright © 2020-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: iotop
# Summary: Test iotop
# - Check basic functionality of iotop
# - Run iotop in background and create some load
# - Make sure load is detected in the report
# Maintainer: Michael Grifalconi <mgrifalconi@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    zypper_call 'in iotop';

    # Test iotop with several options
    assert_script_run("iotop -bakPtn 2");

    # Test under load
    assert_script_run('(iotop -baoqn 10 > iotop.log &)');
    assert_script_run("time dd if=/dev/zero of=./file.img bs=1k count=500000 status=none");
    assert_script_run("wait");
    assert_script_run("grep 'dd if=/dev/zero of=./file.img' iotop.log");

    # Cleanup
    assert_script_run("rm file.img iotop.log");

}

1;
