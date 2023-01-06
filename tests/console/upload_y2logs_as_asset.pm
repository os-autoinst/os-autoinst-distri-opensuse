# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Upload the logs compressed in logs_from_installation_system as asset,
# so they can be parsed after reboot in the test suite "logs_from_installation_system"
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;

sub run {
    select_console 'root-console';
    upload_asset('/tmp/y2logs.tar.bz2');
}

1;
