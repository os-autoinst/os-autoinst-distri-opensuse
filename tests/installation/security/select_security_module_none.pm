# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Select 'None' Major Linux Security Module in Security Configuration
# in the installer.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';

sub run {
    $testapi::distri->get_installation_settings()->access_security_options();
    $testapi::distri->get_security_configuration()->select_security_module('None');
}

1;
