# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Enable import SSH host keys
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';

sub run {
    $testapi::distri->get_installation_settings()->access_ssh_import_options();
    $testapi::distri->get_ssh_import_settings()->enable_ssh_import();
    $testapi::distri->get_ssh_import_settings()->accept();
}

1;
