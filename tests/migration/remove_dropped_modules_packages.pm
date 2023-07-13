# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Register again is system is un-registered on SCC side, then
# remove -release packages from dropped modules before installation to avoid related warnings.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use migration;    #

sub run {
    select_console 'root-console';
    remove_dropped_modules_packages if (get_var('DROPPED_MODULES'));
}

1;
