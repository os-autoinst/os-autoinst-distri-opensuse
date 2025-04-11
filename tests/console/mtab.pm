# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Rework the tests layout.
# - Run test as user
# - Run "test -L /etc/mtab"
# - Run "cat /etc/mtab"
# - Save screenshot
# Maintainer: Alberto Planas <aplanas@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal qw(select_user_serial_terminal);

sub run {
    select_user_serial_terminal;
    assert_script_run 'test -L /etc/mtab';
    record_info('/etc/mtab', script_output('cat /etc/mtab'));
}

1;
