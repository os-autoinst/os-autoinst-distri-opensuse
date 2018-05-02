# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Create partitions for xfstests
# Maintainer: Nathan Zhao <jtzhao@suse.com>
package partition;

use 5.018;
use strict;
use warnings;
use base "opensusebasetest";
use utils;
use testapi;

sub run {
    my $self = shift;
    select_console('root-console');

    # Install parted
    zypper_call("in parted", timeout => 600);

    # Create partitions
    my ($filesystem, $category) = split(/-/, get_var("XFSTESTS"));
    assert_script_run("/usr/share/qa/qa_test_xfstests/partition.py --delhome $filesystem && sync", 600);
}

1;
