# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

## this script test ssh -X-forwarding.
## first open xterm, check ssh socket opening port with ssh with ss
## and type the password with security/no race condition (1).
## after send a command through ssh -X and check with wait_serial (2)


use base "x11test";
use testapi;

sub run() {
    my $self = shift;
    mouse_hide(1);
    x11_start_program("xterm");
    # (1) ss for wait until the socket is opened from localhost.
    # "ESTAB", AND ::1:ssh, AND dport(destination-port) for control with exactitude, that a inc. port from ssh only from localhost is open.
    script_run("for i in {1..100}; do /usr/sbin/ss -at dport = :ssh | tail -n1 >/dev/$serialdev; sleep 3; done & ");
    script_run("ssh  -o  \"StrictHostKeyChecking no\" -XC root\@localhost \" echo \"TEST SSH-X-forwarding OK \" >/dev/$serialdev; \" ");
    # (2)
    wait_serial('ESTAB.*::1:ssh') || die 'SSH -X forwarding port could not be opened. Network Problem ? ';
    type_string "$password\n";
    wait_serial('TEST SSH-X-forwarding OK') || die "SSH -X ERROR. Port/Socket Opened but something went wrong with xterm";
    # close xterm
    type_string("exit\n");
}

1;
# vim: set sw=4 et:
