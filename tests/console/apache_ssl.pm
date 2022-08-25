# SUSE's Apache+SSL tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Enable SSL module on Apache2 server
#          calls setup_apache2 with mode = SSL (lib/apachetest.pm)
#
# Maintainer: Ben Chou <bchou@suse.com>
# Tags: poo#65375, poo#67309, poo#101782

use base "consoletest";
use testapi;
use strict;
use warnings;
use apachetest;
use utils 'clear_console';

sub run {
    my $self = shift;
    select_console 'root-console';
    setup_apache2(mode => 'SSL');
}

sub test_flags {
    return {fatal => 0};
}

1;
