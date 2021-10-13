# SUSE's Apache+NSSFips tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Enable NSS module for Apache2 server with NSSFips on
# Maintainer: Ben Chou <bchou@suse.com>

use strict;
use warnings;
use base "consoletest";
use testapi;
use apachetest;

sub run {
    select_console 'root-console';
    setup_apache2(mode => 'NSSFIPS');
}

1;
