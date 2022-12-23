# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that install urls matches the expected one.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;
use repo_tools 'validate_install_repo';


sub run {
    select_console 'install-shell';
    validate_install_repo;
    select_console 'installation';
}

1;
