# Evolution tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case #1503857: Evolution First time launch and setup assistant
# Maintainer: Qingming Su <qingming.su@suse.com>

use strict;
use base "x11regressiontest";
use testapi;
use utils;

sub run() {
    my $self        = shift;
    my $mail_box    = 'nooops_test3@aim.com';
    my $mail_passwd = 'opensuse';

    mouse_hide(1);

    # Clean and Start Evolution
    # Follow the wizard to setup mail account
    $self->start_evolution($mail_box);
    assert_screen "evolution_wizard-account-summary", 60;
    if (sle_version_at_least('12-SP2')) {
        assert_and_click "evolution-option-next";
    }
    else {
        send_key $self->{next};
    }
    assert_screen "evolution_wizard-done";
    send_key "alt-a";
    assert_screen "evolution_mail-auth";
    type_string "$mail_passwd";
    send_key "ret";
    if (check_screen "evolution_mail-init-window") {
        send_key "super-up";
    }
    assert_screen "evolution_mail-max-window";

    # Help
    assert_screen_change {
        send_key "alt-h";
    };
    send_key "a";
    assert_screen "evolution_about";
    assert_screen_change {
        send_key "esc";
    };

    # Exit
    send_key "ctrl-q";
    wait_idle;
}

1;
# vim: set sw=4 et:
