# SLE15 migration tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Some modules don't exist on the target product, need to remove these modules before migration
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use testapi;
use migration;

sub run {
    select_console 'root-console';
    deregister_dropped_modules;
}

1;
