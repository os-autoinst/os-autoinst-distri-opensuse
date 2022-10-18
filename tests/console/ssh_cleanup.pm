# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Cleanup ssh test user to prevent the user showing up in
#          displaymanager and confusing other tests
#          - If user sshboy exists, remove the user
#
# Maintainer: QE Core <qe-core@suse.de>
# Tags: poo#65375

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    my $self = shift;
    select_serial_terminal;
    assert_script_run('getent passwd sshboy > /dev/null && userdel -fr sshboy');
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
