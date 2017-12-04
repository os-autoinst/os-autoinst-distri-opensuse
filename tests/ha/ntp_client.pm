# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configure NTP client for HA tests
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use version_utils 'sle_version_at_least';
use testapi;

sub run {
    # No standard NTP client on SLE15, Chrony will be used
    return if sle_version_at_least('15');

    # Configuration of NTP client
    script_run("yast2 ntp-client; echo yast2-ntp-client-status-\$? > /dev/$serialdev", 0);
    assert_screen 'yast2-ntp-client';
    send_key 'alt-b';    # start ntp daemon on Boot
    wait_still_screen 3;
    send_key 'alt-a';    # add new Server
    assert_screen 'yast2-ntp-client-add-source';
    send_key 'alt-s';    # select Server
    wait_still_screen 3;
    send_key 'alt-n';    # Next
    assert_screen 'yast2-ntp-client-add-server';
    type_string 'ns';
    send_key 'alt-o';    # Ok
    assert_screen 'yast2-ntp-client-server-list';
    send_key 'alt-o';    # Ok
    wait_serial('yast2-ntp-client-status-0', 90) || die "'yast2 ntp-client' didn't finish";

    # At least one NTP server is needed
    assert_script_run '(( $(ntpq -p | tail -n +3 | wc -l) > 0 ))';
}

1;
# vim: set sw=4 et:
