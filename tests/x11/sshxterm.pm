# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Rework the tests layout.
# G-Maintainer: Alberto Planas <aplanas@suse.com>

use base "x11test";
use strict;
use testapi;

sub run() {
    my $self = shift;
    mouse_hide(1);
    x11_start_program("xterm");
    type_string("ssh -XC root\@localhost xterm\n");
    assert_screen([qw/ssh-xterm-host-key-authentication ssh-password-prompt/]);
    # if ssh asks for authentication of the key accept it
    if (match_has_tag('ssh-xterm-host-key-authentication')) {
        type_string "yes\n";
        assert_screen "ssh-password-prompt";
    }
    type_string "$password\n";
    assert_screen "ssh-second-xterm";
    for (1 .. 13) { send_key "ret" }
    $self->set_standard_prompt();
    type_string "echo If you can see this text, ssh-X-forwarding  is working.\n";
    assert_screen 'test-sshxterm-1';
    # close both windows, executed in remote session, because we can
    type_string "killall xterm\n";
}

1;
# vim: set sw=4 et:
