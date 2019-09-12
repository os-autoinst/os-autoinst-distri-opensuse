# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test basic journalctl functionality (assert bsc#1063066 is not present)
# - Verify "man -P cat journalctl" for broken man page format
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>
# Tags: bsc#1063066

use base "consoletest";
use strict;
use warnings;
use testapi;

sub run {
    if (script_run('command -v man') == 0) {
        my $output = script_output('man -P cat journalctl');
        record_soft_failure('bsc#1063066 - broken manpage') if ($output =~ m/\s+\.SH /);
    }
}

1;
