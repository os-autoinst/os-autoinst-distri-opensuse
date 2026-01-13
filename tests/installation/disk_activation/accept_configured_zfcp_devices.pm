# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This test module handles ZFCP disk activation
#          through libyui-rest-client.

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';

sub run {
    my $zfcp_configuration_overview = $testapi::distri->get_configured_zfcp_devices();
    $zfcp_configuration_overview->accept_devices();
}

1;
