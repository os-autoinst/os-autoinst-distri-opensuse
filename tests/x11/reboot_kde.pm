# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Reboot from plasma
# Maintainer: Stephan Kulow <coolo@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    send_key "ctrl-alt-delete";    # reboot
    assert_screen 'logoutdialog', 15;
    send_key "tab";
    send_key "tab";
    my $ret;
    for (my $counter = 10; $counter > 0; $counter--) {
        $ret = check_screen "logoutdialog-reboot-highlighted", 3;
        if (defined($ret)) {
            last;
        }
        else {
            send_key "tab";
        }
    }
    # report the failure or green
    unless (defined($ret)) {
        assert_screen "logoutdialog-reboot-highlighted", 1;
    }
    send_key "ret";    # confirm

    if (get_var("SHUTDOWN_NEEDS_AUTH")) {
        assert_screen 'reboot-auth', 15;
        type_password;
        send_key "ret";
    }
    $self->wait_boot;
}

sub test_flags {
    return {milestone => 1};
}

1;

