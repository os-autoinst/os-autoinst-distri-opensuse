# Evolution tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case #1503857: Evolution First time launch and setup assistant
# Maintainer: Qingming Su <qingming.su@suse.com>

use strict;
use warnings;
use base "x11test";
use testapi;
use utils;
use version_utils qw(is_sle is_tumbleweed);

sub evolution_wizard {
    my ($self, $mail_box) = @_;
    # Clean and Start Evolution
    # Follow the wizard to setup mail account
    $self->start_evolution($mail_box);
    assert_screen "evolution_wizard-account-summary", 60;
    assert_and_click "evolution-option-next";

    assert_screen "evolution_wizard-done";
    send_key "alt-a";
}

sub run {
    my $self        = shift;
    my $mail_box    = 'nooops_test3@aim.com';
    my $mail_passwd = 'opensuse';

    mouse_hide(1);
    evolution_wizard($self, $mail_box);

    # init time counter
    my $time_counter = 0;
    while (1) {
        # look for mail authentication window or folders scanning, fail in other situations
        assert_screen([qw(evolution_smoke-detect-folders-scanning evolution_mail-auth)]);
        # break loop and continue with test in case of mail authentication window
        last if (match_has_tag('evolution_mail-auth'));
        # if evolution still hangs on folders scanning after 10 tries, try another mail provider
        if ($time_counter == 10) {
            record_info('Connection problem', "Server is not responding, trying backup email provider.");
            my $mail_box = 'nooops_test3@gmx.com';
            evolution_wizard($self, $mail_box);
            assert_screen "evolution_mail-auth";
            last;
        }
        ++$time_counter;
        sleep 1;
    }

    type_string "$mail_passwd";
    send_key "ret";
    if (check_screen "evolution_mail-init-window", 30) {
        send_key "super-up";
    }
    # tumbleweed may pop another auth window
    if (is_tumbleweed) {
        if (check_screen "evolution_mail-auth", 30) {
            send_key "alt-a";    #disable keyring option, in SP2 or tumbleweed
            send_key "alt-p";
            type_string "$mail_passwd";
            send_key "ret";
        }
    }
    assert_screen "evolution_mail-max-window";

    # Help
    wait_screen_change {
        send_key "alt-h";
    };
    send_key "a";
    assert_screen "evolution_about";
    wait_screen_change {
        send_key "esc";
    };

    # Exit
    send_key "ctrl-q";
}

1;
