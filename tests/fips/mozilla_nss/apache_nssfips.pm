# SUSE's Apache+NSSFips tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Enable NSS module for Apache2 server with NSSFips on
# Maintainer: QE Security <none@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use apachetest;

sub run {
    my $self = shift;
    select_serial_terminal;
    setup_apache2(mode => 'NSSFIPS');
}

1;
