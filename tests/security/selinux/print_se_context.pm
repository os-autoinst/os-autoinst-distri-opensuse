# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test "# ls/id/ps -Z" prints any security context of each
#          file/dir/user/process.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#61783, tc#1741282

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    my $testfile = "foo";

    $self->select_serial_terminal;

    # print security context of file/dir
    assert_script_run("touch $testfile");
    validate_script_output("ls -Z $testfile", sub { m/.*_u:.*_r:.*_t:.*\ .*$testfile/sx });
    assert_script_run("rm -f $testfile");
    validate_script_output("ls -Zd /root", sub { m/.*_u:.*_r:.*_t:.*\ \/root/sx });

    # print security context of current user
    validate_script_output("id -Z", sub { m/.*_u:.*_r:.*_t:.*/sx });

    # print security context of process
    validate_script_output("ps -Z", sub { m/.*_u:.*_r:.*_t:.*\ .*bash/sx });
}

1;
