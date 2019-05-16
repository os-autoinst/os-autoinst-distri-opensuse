# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify default options in Network Configuration during installation
# and modify some of these options.
# Maintainer: Joaquín Rivera <jeriveramoya@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use registration 'assert_registration_screen_present';

sub run {
    if (get_var 'OFFLINE_SUT') {
        assert_screen 'inst-networksettings';
    }
    else {
        assert_registration_screen_present;
        send_key 'alt-w';    # Network Configuration
        assert_screen 'inst-network';
        send_key 'alt-s';    # Hostname/DNS
        assert_screen 'inst-network-hostname-dns-tab';
        assert_and_click 'inst-network-hostname-dhcp';
        assert_and_click 'inst-network-hostname-dhcp-modified';
    }
    send_key $cmd{next};
}

1;
