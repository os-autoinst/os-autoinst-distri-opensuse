# SLE15 migration tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: LTSS is not supported to do migration, need to deregiter it before migration
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use registration qw(remove_suseconnect_product);

sub run {
    remove_suseconnect_product('SLES-LTSS');
}

1;

