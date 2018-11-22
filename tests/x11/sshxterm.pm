# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Ensure ssh X-forwarding is working
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    mouse_hide(1);
    x11_start_program('xterm');
    prepare_ssh_localhost_key_login $username;
    type_string("ssh -XC root\@localhost xterm\n");
    assert_screen([qw(ssh-xterm-host-key-authentication ssh-second-xterm)]);
    # if ssh asks for authentication of the key accept it
    if (match_has_tag('ssh-xterm-host-key-authentication')) {
        type_string "yes\n";
    }
    assert_screen "ssh-second-xterm";
    $self->set_standard_prompt();
    $self->enter_test_text('ssh-X-forwarding', cmd => 1);
    assert_screen 'test-sshxterm-1';
    # close both windows, executed in remote session, because we can
    type_string "killall xterm\n";
}

1;
