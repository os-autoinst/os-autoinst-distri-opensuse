# SUSE's openQA tests
#
# Copyright © 2019-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test lshw installation and verify that the output seems properly formatted
# Maintainer: Timo Jyrinki <tjyrinki@suse.com>

use strict;
use warnings;
use base 'consoletest';
use testapi;
use utils;

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    zypper_call('in lshw libxml2-tools');

    # Check various output formats, -sanitize is used to not spill test machine serial numbers into public
    # On some architectures fields like "product" or "vendor" or section "*-pci" might not exist, so trying a common base.
    assert_script_run("lshw -sanitize | grep -A5 'description'");
    assert_script_run("lshw -sanitize | grep -A5 '\\*-memory\$'");
    assert_script_run("lshw -sanitize | grep -A5 '\\*-network'");
    assert_script_run("lshw -html -sanitize");
    assert_script_run("lshw -xml -sanitize");
    assert_script_run("lshw -json -sanitize");
    assert_script_run("lshw -businfo");
    # Check that XML is properly formatted (also empty output would cause an error)
    assert_script_run("lshw -xml | xmllint -noout -");
    # Check that variants of the class option are still supported
    assert_script_run("lshw -class processor");
    assert_script_run("lshw -c processor");
    assert_script_run("lshw -C processor");
}

1;
