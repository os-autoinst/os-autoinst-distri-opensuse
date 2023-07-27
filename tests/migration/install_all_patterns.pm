# SLE15 migration tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install patterns for allpatterns cases before conducting migration
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi qw(select_console);
use utils qw(install_patterns);

sub run {
    select_console 'root-console';
    install_patterns();
}

1;

