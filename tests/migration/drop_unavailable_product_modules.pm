# SLE15 migration tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Some modules don't exist on the target product, need to remove these modules before migration
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use migration;

sub run {
    select_console 'root-console';
    deregister_dropped_modules;
}

1;
