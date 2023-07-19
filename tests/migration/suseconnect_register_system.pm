# SLE15 migration tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Register the original system before migration
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "y2_module_consoletest";
use strict;
use warnings;
use testapi;
use registration;

sub run {
    select_console 'root-console';

    register_product();
    register_addons_cmd();
}

1;
