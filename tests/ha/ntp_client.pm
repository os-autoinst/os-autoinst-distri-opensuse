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

use base 'hacluster';
use strict;
use testapi;

sub run {
    my $self = shift;

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
    $self->clear_and_verify_console;
    assert_script_run '(( $(ntpq -p | tail -n +3 | wc -l) > 0 ))';
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

sub post_fail_hook {
    my $self = shift;

    # Save a screenshot before trying further measures which might fail
    save_screenshot;

    # Try to save logs as a last resort
    $self->export_logs();
}

1;
# vim: set sw=4 et:
