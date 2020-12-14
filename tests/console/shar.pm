# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Package: sharutils diffutils
# Summary: This will test the shar (SHELL ARCHIVE) tool
# Maintainer: Dominik Heidler <dominik@heidler.eu>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils;

sub run {
    my $self = shift;

    select_console 'root-console';
    zypper_call('in sharutils');

    if (check_var('MACHINE', 'RPi3') || check_var('MACHINE', 'RPi4')) {
        select_console 'root-console';
        zypper_call('in diffutils');
    }

    select_console 'user-console';
    assert_script_run('sh ~/data/shar_testdata.sh');
    assert_script_run('file shar_testdata/suse.png | grep "600 x 550"');
    assert_script_run('head -1 shar_testdata/hallo.txt | grep "Hallo Welt"');
    assert_script_run('shar shar_testdata > a.sh');
    assert_script_run('mkdir a');
    assert_script_run('unshar -d a a.sh');
    assert_script_run('diff -ru shar_testdata a/shar_testdata');
}

1;

