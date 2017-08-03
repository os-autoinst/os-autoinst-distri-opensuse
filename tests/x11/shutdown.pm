# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Initiate a system shutdown, taking care of differences between the desktops
#   don't use x11test, the end of this is not a desktop
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "opensusebasetest";
use strict;
use testapi;
use utils;

sub run {
    my $self = shift;
    # Make some information available on common systems to help debug shutdown issues.
    if (get_var('DESKTOP', '') =~ qr/gnome|kde/) {
        x11_start_program('xterm');
        script_sudo(q{echo 'ForwardToConsole=yes' >> /etc/systemd/journald.conf});
        script_sudo(q{echo 'MaxLevelConsole=debug' >> /etc/systemd/journald.conf});
        script_sudo(qq{echo 'TTYPath=/dev/$serialdev' >> /etc/systemd/journald.conf});
        script_sudo(q{systemctl restart systemd-journald});
        type_string("exit\n");
    }
    $self->{await_shutdown} = 0;
    power_action('poweroff', keepconsole => 1);
    $self->{await_shutdown} = 1;
}

sub test_flags {
    return {norollback => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    # In case plymouth splash shows up and the shutdown is blocked, show
    # console logs - save screen of console (plymouth splash screen in disabled at boottime)
    send_key('esc') if $self->{await_shutdown};
    save_screenshot;
}

1;
# vim: set sw=4 et:
