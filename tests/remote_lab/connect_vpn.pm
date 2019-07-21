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
use testapi;
use utils;

sub run {
    my ($self) = @_;
    my $vpn_username = get_required_var('VPN_USERNAME');
    my $vpn_endpoint = get_var('VPN_ENDPOINT', 'asa003b.centers.ihost.com');
    my $vpn_group    = get_var('VPN_GROUP',    'ACC');
    # nohup should already go to background but during test development I
    # observed that it still blocked the terminal – regardless of e.g. using a
    # virtio serial terminal or VNC based – so let's force it to the
    # background.
    # accessing shell variables for the (secret) passwords defined in setup_vpn.
    script_run "(echo \$vpn_password | nohup openconnect --user=$vpn_username --passwd-on-stdin --authgroup=$vpn_group $vpn_endpoint > vpn.log &)", 0;
    wait_serial 'Welcome to the IBM Systems WW Client Experience Center';
}

sub post_fail_hook {
    upload_logs 'vpn.log';
}

1;
