# SUSE's Apache+NSS tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Enable NSS module for Apache2 server
# - calls setup_apache2 with mode = NSS (lib/apachetest.pm)
# Maintainer: Ben Chou <BChou@suse.com>

use strict;
use warnings;
use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use apachetest;

sub run {
    select_serial_terminal;
    setup_apache2(mode => 'NSS');
}

1;
