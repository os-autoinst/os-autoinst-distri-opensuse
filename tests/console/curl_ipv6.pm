# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: curl libcurl4
# Summary: Test curl fallback from IPv6 to IPv4
# - switch to normal user
# - curl a website
# - ensure that curl and libcurl4 are installed
# Maintainer: QE Core <qe-core@suse.de>
# Tags: bsc#598574

use base "consoletest";
use testapi;
use strict;
use warnings;

sub run {
    select_console 'user-console';
    assert_script_run('curl -6 www3.zq1.de/test.txt');
    assert_script_run('rpm -q curl libcurl4');
}

1;
