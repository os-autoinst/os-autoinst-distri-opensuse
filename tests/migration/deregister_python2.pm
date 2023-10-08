# SLE15 migration tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Python2 module doesn't exist since SLE15SP3, need to remove it before migration
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use registration qw(remove_suseconnect_product get_addon_fullname);

sub run {
    remove_suseconnect_product(get_addon_fullname('python2'));
}

1;

