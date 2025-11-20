# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: term openssh
# Summary: Ensure ssh X-forwarding is working
# - Launch default gui terminal
# - Run "SSH_AUTH_SOCK=0 ssh -XC localhost <default-gui-terminal>"
# - Check if another <default-gui-terminal> opened
# - Check for "If you can see this text ssh-X-forwarding is working"
# - Kill <default-gui-terminal>
# Maintainer: QE Core <qe-core@suse.de>

use base "x11test";
use testapi;
use x11utils 'default_gui_terminal';

sub run {
    my ($self) = @_;
    select_console 'x11';
    my $gui_term = default_gui_terminal();
    mouse_hide(1);
    ensure_installed("xauth");
    x11_start_program($gui_term);
    enter_cmd("ssh -o StrictHostKeyChecking=no -XC root\@localhost $gui_term");
    assert_screen "ssh-second-$gui_term", 30;
    $self->set_standard_prompt();
    $self->enter_test_text('ssh-X-forwarding', cmd => 1);
    assert_screen "sshx-text-$gui_term", 30;
    # close both windows, executed in remote session, because we can
    enter_cmd "killall -r $gui_term";
}

1;
