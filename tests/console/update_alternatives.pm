# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: console/update_alternatives test for bsc#969171
# - Run "stat -c"%N" -L /etc/alternatives/*" to check for broken links
# - Capture an screenshot
# Maintainer: Ondřej Súkup <osukup@suse.cz>

use base "consoletest";
use strict;
use warnings;
use testapi;

sub run {
    select_console('user-console');
    assert_script_run('stat -c"%N" -L /etc/alternatives/* >/dev/null');    # call stat on all files in /etc/alternatices an report to stderr broken links
    save_screenshot;
}

1;
