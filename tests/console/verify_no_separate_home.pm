# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: util-linux
# Summary: Verification module. Asserts if /home is not located on the separate
# partition/volume.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings FATAL => 'all';
use testapi;
use Test::Assert 'assert_equals';

sub run {
    select_console 'root-console';

    my $root_device = script_output("findmnt -nrvo SOURCE -T /");
    my $home_device = script_output("findmnt -nrvo SOURCE -T /home");
    assert_equals($root_device, $home_device, "/home is on a separate partition");
}

1;
