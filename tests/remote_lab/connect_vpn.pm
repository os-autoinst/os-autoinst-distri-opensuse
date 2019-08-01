# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Connect VPN to a remote lab using openconnect
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: https://progress.opensuse.org/issues/49901

use base 'opensusebasetest';
use strict;
use warnings;
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
