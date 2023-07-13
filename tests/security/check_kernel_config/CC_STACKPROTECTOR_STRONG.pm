# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: switch from CC_STACKPROTECTOR to CC_STACKPROTECTOR_STRONG in the kernel.
# This provides better protection against stack based buffer overflows.
# The feature is not included in s390x platform yet.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#64084, tc#1744070

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use Utils::Architectures;
use utils;

sub run {
    # check the kernel configuration file to make sure the parameter is there
    if (!is_s390x) {
        validate_script_output "cat /boot/config-`uname -r`|grep CONFIG_STACKPROTECTOR", qr/CONFIG_STACKPROTECTOR_STRONG=y/;
    }
    else {
        my $results = script_run("grep CONFIG_STACKPROTECTOR_STRONG=y /boot/config-`uname -r`");
        if (!$results) {
            die("Error: the kernel parameter is wrongly configured on s390x platform");
        }
    }

}

1;
