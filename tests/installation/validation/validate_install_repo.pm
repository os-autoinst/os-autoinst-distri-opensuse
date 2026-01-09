# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that install urls matches the expected one.
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';
use testapi;
use repo_tools 'validate_install_repo';


sub run {
    select_console 'install-shell';
    validate_install_repo;
    select_console 'installation';
}

1;
