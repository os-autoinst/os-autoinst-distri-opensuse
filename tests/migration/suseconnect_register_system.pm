# SLE15 migration tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Register the original system before migration
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "y2_module_consoletest";
use testapi;
use registration;

sub run {
    select_console 'root-console';

    register_product();
    register_addons_cmd();
}

1;
