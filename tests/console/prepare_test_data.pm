# SUSE's openQA tests
#
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: prepare test data
# Maintainer: Zaoliang Luo <zluo@suse.de>

use base "consoletest";
use testapi;
use utils;
use strict;

sub run {
    my $self = @_;
    $self->select_serial_terminal(0);

    assert_script_run "curl -L -v -f " . autoinst_url('/data') . " > test.data";
    assert_script_run " cpio -id < test.data";
    script_run "ls -al data";
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
