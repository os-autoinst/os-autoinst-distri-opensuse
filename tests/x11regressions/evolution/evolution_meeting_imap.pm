# Evolution tests
#
# Copyright © 2016 SUSE LLC

# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Test Case #*************
use base "x11regressiontest";
use strict;
use testapi;
use utils;


sub setup {

    my ($self, $i) = @_;
    my $config        = $self->getconfig_emailaccount;
    my $mail_box      = $config->{$i}->{mailbox};
    my $mail_server   = $config->{$i}->{sendServer};
    my $mail_user     = $config->{$i}->{user};
    my $mail_passwd   = $config->{$i}->{passwd};
    my $mail_sendport = $config->{$i}->{sendport};
    my $mail_recvport = $config->{$i}->{recvport};
    my $next          = "alt-o";
    print $next;
    mouse_hide(1);
    if (sle_version_at_least('12-SP2')) {
        $next = "alt-n";
    }
    # Clean and Start Evolution
    x11_start_program("xterm -e \"killall -9 evolution; find ~ -name evolution | xargs rm -rf;\"");
    x11_start_program("evolution");
    # Follow the wizard to setup mail account
    assert_screen [qw/evolution-default-client-ask test-evolution-1/];
    if (match_has_tag 'evolution-default-client-ask') {
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

    # setup reciving protocol as imap.
    assert_screen "evolution_wizard-receiving";
    wait_screen_change {
        send_key "alt-t";
    };
    send_key "ret";
    send_key_until_needlematch "evolution_wizard-receiving-imap", "down", 10, 3;
    wait_screen_change {
        send_key "ret";
    };

    wait_screen_change {
        send_key "alt-s";
    };
    type_string "$mail_server";
    wait_screen_change {
        send_key "alt-p";
    };
    type_string "$mail_recvport";
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
    send_key "$next";
    if (sle_version_at_least('12-SP2')) {
        send_key "ret";    #only need in SP2 or later
    }
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
    type_string "$mail_server";
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
    #    save_screenshot();
    type_string "$mail_user";

    send_key "$next";
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

#Setup mail account by auto lookup
sub auto_setup {
    my ($self, $i) = @_;
    my $config        = $self->getconfig_emailaccount;
    my $mail_box      = $config->{$i}->{mailbox};
    my $mail_server   = $config->{$i}->{sendServer};
    my $mail_user     = $config->{$i}->{user};
    my $mail_passwd   = $config->{$i}->{passwd};
    my $mail_sendport = $config->{$i}->{sendport};
    my $mail_recvport = $config->{$i}->{recvport};
    my $next          = "alt-o";
    print $next;
    if (sle_version_at_least('12-SP2')) {
        $next = "alt-n";
    }

    # Clean and Start Evolution
    x11_start_program("xterm -e \"killall -9 evolution; find ~ -name evolution | xargs rm -rf;\"");
    x11_start_program("evolution");
    # Follow the wizard to setup mail account
    assert_screen [qw/evolution-default-client-ask test-evolution-1/];
    if (match_has_tag 'evolution-default-client-ask') {
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
    send_key "$next";
    assert_screen "evolution_wizard-skip-lookup";
    assert_screen "evolution_wizard-account-summary";

    #if used Yahoo account, need disabled Yahoo calendar and tasks
    if ($i eq "Yahoo") {
        send_key "alt-l";
    }
    send_key "$next";
    if (sle_version_at_least('12-SP2')) {
        send_key "$next";    #only in 12-SP2 or later
        send_key "ret";
    }
    assert_screen "evolution_wizard-done";
    send_key "alt-a";
    if (check_screen "evolution_mail-auth") {
        if (sle_version_at_least('12-SP2')) {
            send_key "alt-a";    #disable keyring option, only in SP2 or later
            send_key "alt-p";
        }
        type_string "$mail_passwd";
        send_key "ret";
    }
    if (check_screen "evolution_mail-init-window") {
        send_key "super-up";
    }
    assert_screen "evolution_mail-max-window";
}

sub unread_mail {
    # Make all existing mails as read
    assert_screen "evolution_mail-online", 240;
    send_key "alt-w";
    send_key "ret";
    send_key_until_needlematch "evolution_mail-show-unread", "down", 15, 3;
    send_key "ret";
    send_key "alt-n";
    send_key "ret";
    send_key_until_needlematch "evoltuon_mail_show-allcount", "down", 5, 3;
    send_key "ret";
    save_screenshot();
    send_key "alt-c";
    type_string "meeting";
    send_key "ret";
    wait_idle;
    if (!check_screen "evolution_mail-search-empty") {
        send_key "ret";
        send_key "ctrl-a";
        send_key "ctrl-k";
        save_screenshot();
    }
    assert_screen "evolution_mail-ready", 60;
}

sub send_meeting_requst {

    my ($self, $sender, $receiver) = @_;
    my $config      = $self->getconfig_emailaccount;
    my $mail_box    = $config->{$receiver}->{mailbox};
    my $mail_passwd = $config->{$sender}->{passwd};

    #create new meeting
    send_key "shift-ctrl-e";
    assert_screen "evolution_mail-compse_meeting", 30;
    send_key "alt-a";
    sleep 2;
    type_string "$mail_box";
    send_key "alt-s";
    if (sle_version_at_least('12-SP2')) {
        send_key "alt-s";    #only need in sp2
    }
    type_string "this is a imap test meeting";
    send_key "alt-l";
    type_string "the location of this meetinng is conference room";
    assert_screen "evolution_mail-compse_meeting", 60;
    send_key "ctrl-s";
    assert_screen "evolution_mail-sendinvite_meeting", 60;
    send_key "ret";
    if (check_screen "evolution_mail-auth") {
        if (sle_version_at_least('12-SP2')) {
            send_key "alt-a";    #disable keyring option, only need in SP2 or later
            send_key "alt-p";
        }
        type_string "$mail_passwd";
        send_key "ret";
    }
    assert_screen "evolution_mail-compse_meeting", 60;
    send_key "ctrl-w";
    if (check_screen "evolution_mail-save_meeting_dialog") {
        send_key "ret";
    }
    if (check_screen "evolution_mail-send_meeting_dialog") {
        send_key "ret";
    }
    if (check_screen "evolution_mail-meeting_error_handle") {
        send_key "alt-t";
    }
}

sub check_new_mail {
    assert_screen "evolution_mail-online", 240;
    send_key "f12";
    wait_still_screen;
    assert_screen "evolution_mail-online", 240;
    send_key "alt-w";
    send_key "ret";
    send_key_until_needlematch "evolution_mail-show-unread", "down", 15, 3;
    send_key "ret";
    send_key "alt-n";
    send_key "ret";
    send_key_until_needlematch "evoltuon_mail_show-allcount", "down", 5, 3;
    send_key "ret";
    send_key "alt-c";
    type_string "meeting";
    send_key "ret";
    assert_and_click "evolution_meeting-view-new";
    send_key "ret";
    assert_screen "evolution_meeting_open-meeting", 120;

    # Delete the message and expunge the deleted item
    send_key "ctrl-w";
    save_screenshot();
    send_key "ctrl-e";
    if (check_screen "evolution_mail-expunge") {
        send_key "alt-e";
    }
    assert_screen "evolution_mail-ready";
}

sub run() {
    my $self = shift;

    #setup account Yahoo and unread all meeting mails.
    #    setup ($self, "suseTest19");
    $self->setup("suseTest19");
    unread_mail;
    # Exit
    send_key "ctrl-q";
    wait_idle;

    #Setup account Yahoo, and use it to send a meeting
    #    auto_setup ($self, "Yahoo");
    $self->auto_setup("Yahoo");
    #send meet request by Yahoo
    #    send_meeting_requst ($self, "Yahoo", "suseTest19",);
    $self->send_meeting_requst("Yahoo", "suseTest19");
    assert_screen "evolution_mail-ready", 60;
    # Exit
    send_key "alt-f";
    send_key "q";
    wait_idle;

    #login with SuseTest19 account and check meeting request.
    #    setup ($self, "suseTest19");
    $self->setup("suseTest19");
    check_new_mail;
    wait_idle;
    # Exit
    send_key "ctrl-q";
}

1;
# vim: set sw=5 set:
