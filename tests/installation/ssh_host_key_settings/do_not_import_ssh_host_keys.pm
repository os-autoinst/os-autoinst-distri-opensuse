# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Disable import SSH host keys
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';

sub run {
    $testapi::distri->get_installation_settings()->access_ssh_import_options();
    $testapi::distri->get_ssh_import_settings()->disable_ssh_import();
    $testapi::distri->get_ssh_import_settings()->accept();
}

1;
