# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Select 'None' Major Linux Security Module in Security Configuration
# in the installer.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';

sub run {
    $testapi::distri->get_installation_settings()->access_security_options();
    $testapi::distri->get_security_configuration()->select_security_module('None');
}

1;
