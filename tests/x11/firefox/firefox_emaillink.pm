# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaFirefox
# Summary: Firefox emaillink test (Case#1436117)
# - Launch xterm, kill firefox, cleanup previous firefox configuration, launch
# firefox
# - Open file menu and "Email link"
# - Handle sending email using email client
# - Exit firefox
# Maintainer: wnereiz <wnereiz@github>

use strict;
use warnings;
use base "x11test";
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    my $next_key = "alt-o";

    if (is_sle('12-SP2+')) {
        $next_key = "alt-n";
    }

    $self->start_firefox_with_profile;

    # Email link
    send_key_until_needlematch 'firefox-file-menu', 'alt-f', 4, 15;
    send_key "e";
    assert_screen(['firefox-email_link-welcome', 'firefox-email-mutt', 'firefox-email_link-send'], 90);
    if (match_has_tag('firefox-email-mutt')) {
        send_key 'y';    # yes
        sleep 1;
        enter_cmd "test\@suse.com";
        sleep 1;
        send_key 'home';    # beginning of subject
        sleep 1;
        send_key 'ctrl-k';    # delete existing subject
        sleep 1;
        enter_cmd "test subject";
        sleep 1;
        send_key 'd';
        sleep 1;
        send_key 'd';
        sleep 1;
        send_key 'i';    # enter vim insert mode
        sleep 1;
        enter_cmd "test email";
        sleep 1;
        send_key 'esc';    # escape insert mode
        sleep 1;
        save_screenshot;
        enter_cmd ":wq";
        sleep 1;
        assert_screen('mutt-send');
        send_key 'y';
    }
    elsif (match_has_tag('firefox-email_link-welcome')) {
        send_key $next_key;

        wait_still_screen 3;
        send_key $next_key;

        wait_still_screen 3;
        send_key "alt-a";
        type_string 'test@suse.com';
        send_key $next_key;

        sleep 1;
        send_key "alt-s";    #Skip

        assert_screen('firefox-email_link-settings_receiving', 90);
        send_key "alt-s";    #Server
        type_string "imap.suse.com";
        send_key "alt-n";    #Username
        type_string "test";
        if (is_sle('12-SP2+')) {
            assert_and_click "evolution-option-next";
            wait_still_screen 3;
            assert_and_click "evolution-option-next";
        }
        else {
            send_key $next_key;
            wait_still_screen 3;
            send_key $next_key;
        }

        assert_screen('firefox-email_link-settings_sending');
        send_key "alt-s";    #Server
        type_string "smtp.suse.com";
        wait_screen_change {
            send_key $next_key;
        };

        wait_still_screen 3;
        if (is_sle('12-SP2+')) {
            assert_and_click "evolution-option-next";
        }
        else {
            send_key $next_key;
        }

        wait_still_screen 3;
        send_key "alt-a";
        assert_screen('firefox-email_link-send');
    }
    elsif (match_has_tag('firefox-email_link-send')) {
        wait_screen_change {
            send_key 'esc';
        };
    }

    $self->exit_firefox;
}
1;
