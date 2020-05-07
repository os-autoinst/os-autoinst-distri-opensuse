# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Ensure ssh X-forwarding is working
# - Launch xterm
# - Run "SSH_AUTH_SOCK=0 ssh -XC root@localhost xterm"
# - Check if another xterm opened
# - Check for "If you can see this text ssh-X-forwarding is working"
# - Kill xterm
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    mouse_hide(1);
    x11_start_program('xterm');
    type_string("ssh -XC root\@localhost xterm\n");
    assert_screen "ssh-second-xterm";
    $self->set_standard_prompt();
    $self->enter_test_text('ssh-X-forwarding', cmd => 1);
    assert_screen 'test-sshxterm-1';
    # close both windows, executed in remote session, because we can
    type_string "killall xterm\n";
}

1;
