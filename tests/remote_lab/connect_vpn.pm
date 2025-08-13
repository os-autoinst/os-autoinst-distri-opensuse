# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Connect VPN to a remote lab using openconnect
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: https://progress.opensuse.org/issues/49901

use base 'opensusebasetest';
use Remote::Lab 'connect_vpn';
use testapi;


sub run {
    select_console 'tunnel-console';
    connect_vpn();
}

sub post_fail_hook {
    upload_logs 'vpn.log';
}

1;
