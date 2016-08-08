# Evolution tests
#
# Copyright © 2016 SUSE LLC

# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Test Case #1503976 Pop Meeting

use base "x11regressiontest";
use strict;
use warnings;
use testapi;
use utils;
use POSIX qw(strftime);


sub setup_pop {

    my ($self, $i) = @_;
    my $config          = $self->getconfig_emailaccount;
    my $mail_box        = $config->{$i}->{mailbox};
    my $mail_sendServer = $config->{$i}->{sendServer};
    my $mail_recvServer = $config->{$i}->{recvServer};
    my $mail_user       = $config->{$i}->{user};
    my $mail_passwd     = $config->{$i}->{passwd};
    my $mail_sendport   = $config->{$i}->{sendport};
    my $mail_recvport   = $config->{$i}->{recvport};
    my $next            = "alt-o";
    mouse_hide(1);
    if (sle_version_at_least('12-SP2')) {
        $next = "alt-n";
    }
    # Clean and Start Evolution
    x11_start_program("xterm -e \"killall -9 evolution; find ~ -name evolution | xargs rm -rf;\"");
    x11_start_program("evolution");
    # Follow the wizard to setup mail account
    assert_screen [qw/evolution-default-client-ask test-evolution-1/];
    if (check_screen 'evolution-default-client-ask') {
        assert_and_click "evolution-default-client-agree";
        assert_screen "test-evolution-1";
    }
    send_key "$next";
    assert_screen "evolution_wizard-restore-backup";
    send_key "$next";
    assert_screen "evolution_wizard-identity";
    wait_screen_change {
        send_key "alt-e";
    };
    type_string "SUSE Test";
    wait_screen_change {
        send_key "alt-a";
    };
    type_string "$mail_box";
    sleep 1;
    save_screenshot();
    send_key "$next";
    if (check_screen "evolution_wizard-skip-lookup") {
        send_key "alt-s";
    }

    # setup reciving protocol as pop
    assert_screen "evolution_wizard-receiving";
    wait_screen_change {
        send_key "alt-t";
    };
    send_key "ret";
    send_key_until_needlematch "evolution_wizard-receiving-pop", "down", 10, 3;
    wait_screen_change {
        send_key "ret";
    };

    wait_screen_change {
        send_key "alt-s";
    };
    type_string "$mail_recvServer";
    #No need set receive port with POP
    #    wait_screen_change {
    #        send_key "alt-p";
    #    };
    #    type_string "$mail_recvport";
    wait_screen_change {
        send_key "alt-n";
    };
    type_string "$mail_user";
    wait_screen_change {
        send_key "alt-m";
    };
    send_key "ret";
    send_key_until_needlematch "evolution_wizard-receiving-ssl", "down", 5, 3;
    wait_screen_change {
        send_key "ret";
    };
    # add self-signed CA with internal account
    if ($i =~ m/internal/) {
        assert_and_click "evolution_wizard-receiving-checkauthtype";
        assert_screen "evolution_mail_meeting_trust_ca";
        send_key "alt-a";
        wait_screen_change {
            send_key "$next";
            send_key "ret";
        }
    }
    else {
        send_key "$next";
    }
    if (sle_version_at_least('12-SP2')) {
        send_key "ret";    #only need in SP2 or later
    }
    save_screenshot;
    assert_screen "evolution_wizard-receiving-opts";
    send_key "$next";
    if (sle_version_at_least('12-SP2')) {
        send_key "ret";    #only need in SP2 or later
    }

    #setup sending protocol as smtp
    assert_screen "evolution_wizard-sending";
    wait_screen_change {
        send_key "alt-t";
    };
    send_key "ret";
    save_screenshot;
    send_key_until_needlematch "evolution_wizard-sending-smtp", "down", 5, 3;
    wait_screen_change {
        send_key "ret";
    };
    wait_screen_change {
        send_key "alt-s";
    };
    type_string "$mail_sendServer";
    wait_screen_change {
        send_key "alt-p";
    };
    type_string "$mail_sendport";
    wait_screen_change {
        send_key "alt-v";
    };
    wait_screen_change {
        send_key "alt-m";
    };
    send_key "ret";
    send_key_until_needlematch "evolution_wizard-sending-starttls", "down", 5, 3;
    send_key "ret";

    #Known issue: hot key 'alt-y' doesn't work
    #wait_screen_change {
    #   send_key "alt-y";
    #};
    #send_key "ret";
    #send_key_until_needlematch "evolution_wizard-sending-authtype", "down", 5, 3;
    #send_key "ret";
    #Workaround of above issue: click the 'Check' button
    assert_and_click "evolution_wizard-sending-setauthtype";
    send_key_until_needlematch "evolution_wizard-sending-authtype", "down", 5, 3;
    send_key "ret";
    wait_screen_change {
        send_key "alt-n";
    };
    sleep 1;
    type_string "$mail_user";
    # add self-signed CA with internal account
    if ($i =~ m/internal/) {
        assert_and_click "evolution_wizard-sending-checkauthtype";
        assert_screen "evolution_mail_meeting_trust_ca";
        send_key "alt-a";
        wait_screen_change {
            send_key "$next";
            send_key "ret";
        }
    }
    else {
        send_key "$next";
    }
    if (sle_version_at_least('12-SP2')) {
        send_key "ret";    #only in sp2, send ret to next page
    }
    assert_screen "evolution_wizard-account-summary";
    send_key "$next";
    if (sle_version_at_least('12-SP2')) {
        send_key "alt-n";    #only in sp2
        send_key "ret";
    }
    assert_screen "evolution_wizard-done";
    send_key "alt-a";

    if (check_screen "evolution_mail-auth") {
        if (sle_version_at_least('12-SP2')) {
            send_key "alt-a";    #disable keyring option, only in SP2
            send_key "alt-p";
        }
        type_string "$mail_passwd";
        send_key "ret";
    }
    if (check_screen "evolution_mail-init-window") {
        send_key "super-up";
    }
    if (check_screen "evolution_mail-auth") {
        if (sle_version_at_least('12-SP2')) {
            send_key "alt-p";
        }
        type_string "$mail_passwd";
        send_key "ret";
    }
    assert_screen "evolution_mail-max-window";
}

sub run() {
    my $self         = shift;
    my $mail_subject = $self->get_dated_random_string(4);
    #Setup account account A, and use it to send a meeting
    #send meet request by account A
    $self->setup_pop("internal_account_A");
    $self->send_meeting_request("internal_account_A", "internal_account_B", $mail_subject);
    assert_screen "evolution_mail-ready", 60;
    # Exit
    send_key "alt-f";
    send_key "q";
    wait_idle;

    #login with account B and check meeting request.
    $self->setup_pop("internal_account_B");
    $self->check_new_mail_evolution($mail_subject, "internal_account_B", "POP");
    wait_idle;
    # Exit
    send_key "ctrl-q";
}

1;
# vim: set sw=5 set:
