# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "hacluster";
use testapi;

sub run() {
    my $self = shift;
    type_string "yast2 ntp-client\n";
    assert_screen "yast2-ntp-client";
    send_key 'alt-b';    #start ntp daemon on Boot
    send_key 'alt-a';    #add new Server
    assert_screen "yast2-ntp-client-add-source";
    send_key 'alt-n';    #Next
    assert_screen "yast2-ntp-client-add-server";
    type_string "ntp";
    send_key 'alt-o';    #Ok
    assert_screen "yast2-ntp-client-server-list";
    send_key 'alt-o';    #Ok
    wait_still_screen;
    $self->clear_and_verify_console;
    type_string "echo \"ntpcount=`ntpq -p | tail -n +3 | wc -l`\" > /dev/$serialdev\n";
    die "Adding NTP servers failed" unless wait_serial "ntpcount=1";
}

sub test_flags {
    return {fatal => 1};
}

1;
