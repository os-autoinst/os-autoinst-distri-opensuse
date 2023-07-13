# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This test module handles ZFCP disk activation
#          through libyui-rest-client.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';

sub run {
    my $zfcp_configuration_overview = $testapi::distri->get_configured_zfcp_devices();
    $zfcp_configuration_overview->add();
}

1;
