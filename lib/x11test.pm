# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

## no critic (RequireFilenameMatchesPackage);
package x11test;
use base "opensusebasetest";

use strict;
use warnings;
use testapi;
use LWP::Simple;
use Config::Tiny;
use Utils::Architectures;
use utils;
use version_utils qw(is_sle is_leap is_tumbleweed);
use x11utils qw(select_user_gnome start_root_shell_in_xterm handle_gnome_activities);
use POSIX 'strftime';
use mm_network;

sub post_run_hook {
    my ($self) = @_;

    assert_screen('generic-desktop') unless match_has_tag('generic-desktop');
}

sub dm_login {
    assert_screen('displaymanager', 60);
    select_user_gnome;
    assert_screen('originUser-login-dm');
    type_password;
}

# logout and switch window-manager
sub switch_wm {
    assert_and_click "system-indicator";
    assert_and_click "user-logout-sector";
    assert_and_click "logout-system";
    assert_screen "logout-dialogue";
    send_key 'tab' if is_sle('15+');
    send_key "ret";
    dm_login;
}

# shared between gnome_class_switch and gdm_session_switch
sub prepare_sle_classic {
    my ($self) = @_;

    # Log out and switch to GNOME Classic
    assert_screen "generic-desktop";
    $self->switch_wm;
    assert_and_click "displaymanager-settings";
    assert_and_click "dm-gnome-classic";
    send_key "ret";
    assert_screen "desktop-gnome-classic", 350;
    $self->application_test;

    # Log out and switch back to default session
    $self->switch_wm;
    assert_and_click "displaymanager-settings";
    if (is_sle('15+')) {
        assert_and_click 'dm-gnome-shell';
        send_key 'ret';
        handle_gnome_activities;
    }
    else {
        assert_and_click 'dm-sle-classic';
        send_key 'ret';
        assert_screen 'desktop-sle-classic', 350;
    }
}

sub test_terminal {
    my ($self, $name) = @_;
    mouse_hide(1);
    x11_start_program($name);
    # GNOME40 sometimes gets its activities mode incorrectly triggered by x11_start_program
    send_key 'esc' if (check_var("DESKTOP", "gnome") && check_screen "$name-activities");
    $self->enter_test_text($name, cmd => 1);
    assert_screen "test-$name-1";
    send_key 'alt-f4';
}

# Start shotwell and handle the welcome screen, if there
sub start_shotwell {
    x11_start_program('shotwell', target_match => [qw(shotwell-first-launch shotwell-launched)]);
    if (match_has_tag "shotwell-first-launch") {
        wait_screen_change { send_key "ret" };
    }
}

# import_pictures helps shotwell to import test pictures into shotwell's library.
sub import_pictures {
    my ($self, $pictures) = @_;

    # Fetch test pictures to ~/Documents
    foreach my $picture (@$pictures) {
        x11_start_program("wget " . autoinst_url . "/data/x11/$picture -O /home/$username/Documents/$picture", valid => 0);
    }

    # Open the dialog 'Import From Folder'
    wait_screen_change {
        send_key "ctrl-i";
    };
    assert_screen 'shotwell-importing';
    send_key "ctrl-l";
    enter_cmd "/home/$username/Documents";
    send_key "ret";

    # Choose 'Import in Place'
    if (check_screen 'shotwell-import-prompt', 30) {
        send_key "alt-i";
    }
    assert_screen 'shotwell-imported-tip';
    send_key "ret";
    assert_screen 'shotwell-imported';
}

# clean_shotwell helps to clean shotwell's library then remove the test picture.
sub clean_shotwell {
    # Clean shotwell's database
    x11_start_program("rm -rf /home/$username/.local/share/shotwell", valid => 0);
    # Clean shotwell cache files
    x11_start_program("rm -rf /home/$username/.cache/shotwell", valid => 0);
    # Remove test pictures
    x11_start_program("rm /home/$username/Documents/shotwell_test.*", valid => 0);
}

# upload libreoffice specified file into /home/$username/Documents
sub upload_libreoffice_specified_file {

    x11_start_program('xterm');
    assert_script_run('wget ' . autoinst_url . "/data/x11/ooo-test-doc-types.tar.bz2 -O /home/$username/Documents/ooo-test-doc-types.tar.bz2");
    assert_script_run("cd /home/$username/Documents && ls -l");
    # extract the files directly in /home/berhard/Documents, no need to write whole path in libreoffice_open_specified_file
    assert_script_run('tar -xjvf ooo-test-doc-types.tar.bz2 --strip-components 1');
    # delete the archive, to keep the order for already existing needles
    assert_script_run('rm ooo-test-doc-types.tar.bz2');
    send_key "alt-f4";
    wait_still_screen;

}

# cleanup libreoffcie specified file from test vm
sub cleanup_libreoffice_specified_file {

    x11_start_program('xterm');
    assert_script_run("rm -f /home/$username/Documents/{cs,ooo-test-doc-types,template,test}*");
    assert_script_run("ls -l /home/$username/Documents");
    send_key "alt-f4";
    wait_still_screen;

}

# cleanup libreoffice recent open file to make sure libreoffice clean
sub cleanup_libreoffice_recent_file {
    x11_start_program('xterm');
    assert_script_run("rm -rf /home/$username/.config/libreoffice/");
    wait_still_screen;
    send_key "alt-f4";
    x11_start_program('libreoffice');
    wait_still_screen 3;
    assert_screen("welcome-to-libreoffice");
    send_key "ctrl-q";
}

sub open_libreoffice_options {
    if (is_tumbleweed or is_sle('15+')) {
        send_key 'alt-f12';
    }
    else {
        send_key "alt-t";
        wait_still_screen 3;
        send_key "alt-o";
    }
}

# get email account information for Evolution test cases
sub getconfig_emailaccount {
    my ($self) = @_;
    my $local_config = << 'END_LOCAL_CONFIG';
[internal_account_A]
user = admin
mailbox = admin@localhost
passwd = password123
recvport =995
imapport =993
recvServer = localhost
sendServer = localhost
sendport =25

[internal_account_B]
user = nimda
mailbox = nimda@localhost
passwd = password123
recvport =995
imapport =993
recvServer = localhost
sendServer = localhost
sendport =25

[internal_account_C]
user =admin
mailbox =admin@server
passwd =password123
recvport =995
imapport =993
recvServer =10.0.2.101
sendServer =10.0.2.101
sendport =25

[internal_account_D]
user =nimda
mailbox =nimda@server
passwd =password123
recvport =995
imapport =993
recvServer =10.0.2.101
sendServer =10.0.2.101
sendport =25
END_LOCAL_CONFIG

    my $config = Config::Tiny->new;
    $config = Config::Tiny->read_string($local_config);

    return $config;

}

# check and new mail or meeting for Evolution test cases
# It need define seraching key words to serach mail box.

sub check_new_mail_evolution {
    my ($self, $mail_search, $i, $protocol) = @_;
    my $config = $self->getconfig_emailaccount;
    my $mail_passwd = $config->{$i}->{passwd};
    assert_screen "evolution_mail-online", 240;
    send_key 'f12';
    wait_still_screen(2);
    assert_and_click('evolution_mail-auth-unfocused') if check_screen('evolution_mail-auth-unfocused', 2);
    assert_screen ['evolution_mail-auth', 'evolution_mail-max-window'];
    if (match_has_tag "evolution_mail-auth") {
        send_key "alt-a";    #disable keyring option
        send_key "alt-p";
        type_password $mail_passwd;
        send_key "ret";
        assert_screen "evolution_mail-max-window";
    }
    send_key "alt-w";
    send_key "ret";
    wait_still_screen 2;
    send_key_until_needlematch "evolution_mail_show-all", "down", 6, 1;
    send_key "ret";
    wait_still_screen(2);
    send_key "alt-n";
    send_key "ret";
    send_key_until_needlematch "evolution_mail_show-allcount", "down", 6, 1;
    send_key "ret";
    send_key "alt-c";
    type_string "$mail_search";
    wait_still_screen(2);
    send_key "ret";
    assert_and_click "evolution_meeting-view-new";
    send_key "ret";
    assert_screen "evolution_mail_open_mail";
    send_key "ctrl-w";    # close the mail
    save_screenshot();
}

# get a random string with followed by date, it used in evolution case to get a unique email title.
sub get_dated_random_string {
    my ($self, $length) = @_;
    my $ret_string = (strftime "%F", localtime) . "-";
    return $ret_string .= random_string($length);
}

#send meeting request by Evolution test cases
sub send_meeting_request {

    my ($self, $sender, $receiver, $mail_subject) = @_;
    my $config = $self->getconfig_emailaccount;
    my $mail_box = $config->{$receiver}->{mailbox};
    my $mail_passwd = $config->{$sender}->{passwd};

    #create new meeting
    send_key "shift-ctrl-e";
    assert_screen "evolution_mail-compse_meeting", 30;
    wait_screen_change { send_key 'alt-a' };
    wait_still_screen;
    type_string "$mail_box";
    assert_and_click "evolution_meeting-Summary";
    type_string "$mail_subject this is a evolution test meeting";
    send_key "alt-l";
    type_string "the location of this meetinng is conference room";
    assert_screen "evolution_mail-compse_meeting", 60;
    send_key "ctrl-s";
    assert_screen "evolution_mail-sendinvite_meeting", 60;
    send_key "ret";
    wait_still_screen(2, 2);
    assert_screen 'evolution_mail-auth';
    send_key "alt-a";    #disable keyring option
    send_key "alt-p";
    type_password $mail_passwd;
    wait_still_screen(2, 2);
    send_key "ret";
    if (check_screen "evolution_mail-compse_meeting", 5) {
        send_key "ctrl-w";
    }
    wait_still_screen(2);
    send_key 'f12';
    wait_still_screen(2);
    assert_and_click('evolution_mail-auth-unfocused') if check_screen('evolution_mail-auth-unfocused', 2);
    assert_screen ['evolution_mail-auth', 'evolution_mail-max-window'];
    if (match_has_tag "evolution_mail-auth") {
        send_key "alt-a";    #disable keyring option
        send_key "alt-p";
        type_password $mail_passwd;
        send_key "ret";
        assert_screen "evolution_mail-max-window";
    }
    assert_screen [qw(evolution_mail-save_meeting_dialog evolution_mail-send_meeting_dialog evolution_mail-meeting_error_handle evolution_mail-max-window)];
    if (match_has_tag "evolution_mail-save_meeting_dialog") {
        send_key "ret";
    }
    if (match_has_tag "evolution_mail-send_meeting_dialog") {
        send_key "ret";
    }
    if (match_has_tag "evolution_mail-meeting_error_handle") {
        send_key "alt-t";
    }
}

sub setup_pop {
    my ($self, $account) = @_;
    $self->setup_mail_account('pop', $account);
}

sub setup_imap {
    my ($self, $account) = @_;
    $self->setup_mail_account('imap', $account);
}

sub start_evolution {
    # This function removes any previous Evolution configuration, and goes through the first-run config wizard.

    # Test setup
    my ($self, $mail_box) = @_;
    mouse_hide(1);

    # Cleanup past configs  and start Evolution.
    x11_start_program("xterm -e \"killall -9 evolution; find ~ -name evolution | xargs rm -rf;\"", valid => 0);
    x11_start_program('evolution', target_match => [qw(evolution-default-client-ask test-evolution-1 evolution-welcome-not_focused)]);
    # Follow the wizard to setup mail account.
    if (match_has_tag 'evolution-default-client-ask') {
        assert_and_click "evolution-default-client-agree";
        assert_screen "test-evolution-1";
    }
    elsif (match_has_tag "evolution-welcome-not_focused") {
        assert_and_click "evolution-welcome-not_focused";
    }
    # Μake sure the welcome window is maximized and click next.
    send_key "super-up";
    assert_and_click("evolution_welcome-max-window-click");
    # Don't restore from backup and click next.
    assert_and_click("evolution_wizard-restore-backup-click");

    # Move to "Full Name" field and fill it.
    send_key "alt-e";
    wait_still_screen(2);
    type_string "SUSE Test";
    wait_still_screen(2, 2);
    # Move to "Email Address" field and fill it.
    send_key "alt-a";
    type_string_slow "$mail_box";
    wait_still_screen(2, 2);
    save_screenshot();
    send_key 'alt-n';
    if ($mail_box eq 'nooops_test3@aim.com') {
        assert_screen [qw(evolution_wizard-account-summary evolution_wizard-receiving)];
        if (match_has_tag 'evolution_wizard-account-summary') {
            record_info 'found', "$mail_box details resolved";
            assert_and_click "evolution-option-next";
            assert_screen 'evolution_wizard-done';
            send_key 'alt-a';
            wait_still_screen(1);
            send_key 'alt-n';
        }
        else {
            record_soft_failure 'poo#67408';
            send_key 'alt-c';
        }
    }
    else {
        assert_screen 'evolution_wizard-receiving';
    }
    wait_still_screen(2);
}

sub evolution_add_self_signed_ca {
    my ($self, $account) = @_;
    # add self-signed CA with internal account
    if ($account =~ m/internal/) {
        assert_and_click 'evolution_wizard-receiving-checkauthtype';
        assert_screen 'evolution_mail_meeting_trust_ca';
        send_key 'alt-a';
        assert_and_click 'evolution_wizard-receiving';
        send_key $cmd{next};    # select "Next" key
        wait_still_screen(2);
        send_key 'ret';    # Go to next page (previous key just selected the key)
    }
    else {
        send_key $cmd{next};
    }
}

sub setup_mail_account {
    my ($self, $proto, $account) = @_;

    my $config = $self->getconfig_emailaccount;
    my $mail_box = $config->{$account}->{mailbox};
    my $mail_sendServer = $config->{$account}->{sendServer};
    my $mail_recvServer = $config->{$account}->{recvServer};
    my $mail_user = $config->{$account}->{user};
    my $mail_passwd = $config->{$account}->{passwd};
    my $mail_sendport = $config->{$account}->{sendport};
    my $port_key = $proto eq 'pop' ? 'recvport' : 'imapport';
    my $mail_recvport = $config->{$account}->{$port_key};

    $self->start_evolution($mail_box);
    # Open Server Type screen.
    send_key "alt-t";
    wait_still_screen(1);
    send_key_until_needlematch "evolution_wizard-receiving-$proto", "down", 11, 1;
    send_key "alt-s";
    wait_still_screen(1);
    type_string "$mail_recvServer";
    if ($proto eq 'pop') {
        #No need set receive port with POP
    }
    elsif ($proto eq 'imap') {
        send_key "alt-p";
        wait_still_screen(2, 2);
        type_string "$mail_recvport";
    }
    else {
        die "Unsupported protocol: $proto";
    }
    send_key "alt-n";
    wait_still_screen(1);
    type_string "$mail_user";
    send_key "alt-m";
    wait_still_screen(1);
    send_key_until_needlematch "evolution_wizard-receiving-ssl", "down", 6, 1;
    $self->evolution_add_self_signed_ca($account);
    assert_screen [qw(evolution_wizard-receiving-opts evolution_wizard-receiving-not-focused)];
    if (match_has_tag 'evolution_wizard-receiving-not-focused') {
        record_info('workaround', "evolution window not focused, sending key");
        assert_and_click "evolution_wizard-receiving-not-focused";
        if (is_tumbleweed) {
            assert_and_click "evolution_wizard-receiving-not-focused-next";
        }
        else {
            send_key "ret";
        }
        assert_screen "evolution_wizard-receiving-opts";
    }
    send_key "ret";    #only need in SP2 or later, or tumbleweed

    #setup sending protocol as smtp
    assert_screen "evolution_wizard-sending";
    send_key "alt-t";
    wait_still_screen(2);
    send_key "home";
    wait_still_screen(2);
    send_key_until_needlematch "evolution_wizard-sending-smtp", "down", 6, 1;
    send_key "alt-s";
    type_string "$mail_sendServer";
    wait_still_screen(2, 2);
    send_key "alt-p";
    type_string "$mail_sendport";
    wait_still_screen(2);
    send_key "alt-v";
    wait_still_screen(2);
    send_key "alt-m";
    wait_still_screen(2);
    send_key "home";
    #change to use mail-server and SSL
    my $encrypt = get_var('QAM_MAIL_EVOLUTION') ? 'TLS' : 'STARTTLS';
    send_key_until_needlematch "evolution_SSL_wizard-sending-$encrypt", "down", 6, 1;
    assert_and_click "evolution_wizard-sending-setauthtype";
    assert_and_click "evolution_wizard-sending-setauthtype_login";
    wait_screen_change { send_key 'alt-n' };
    type_string "$mail_user";
    assert_and_click("evolution_wizard-sending_username_filled");
    assert_screen "evolution_wizard-account-summary";
    send_key $cmd{next};
    send_key "alt-n";
    send_key "ret";
    assert_screen "evolution_wizard-done";
    send_key "alt-a";
    wait_still_screen(2);
    if (check_screen "evolution_mail-auth", 5) {
        if (is_sle('15+')) {
            send_key "alt-a";    #disable keyring option
        }
        else {
            assert_and_click("disable_keyring_option");
        }
        send_key "alt-p";
        type_password $mail_passwd;
        send_key "ret";
    }
    # Μake sure the welcome window is maximized
    send_key_until_needlematch 'evolution_mail-max-window', 'super-up', 4, 3;
}

# Use AutoConfig file for firefox to predefine some user values
# https://support.mozilla.org/en-US/kb/customizing-firefox-using-autoconfig
sub prepare_firefox_autoconfig {
    my ($self) = @_;
    start_root_shell_in_xterm;

    # Enable AutoConfig by pointing to a cfg file
    type_string(
        q{cat <<EOF > $(rpm --eval %_libdir)/firefox/defaults/pref/autoconfig.js
pref("general.config.filename", "firefox.cfg");
pref("general.config.obscure_value", 0);
EOF
});
    # Create AutoConfig cfg file
    type_string(
        q{cat <<EOF > $(rpm --eval %_libdir)/firefox/firefox.cfg
// Mandatory comment
// https://firefox-source-docs.mozilla.org/browser/components/newtab/content-src/asrouter/docs/first-run.html
pref("browser.aboutwelcome.enabled", false);
pref("browser.startup.upgradeDialog.enabled", false);
pref("privacy.restrict3rdpartystorage.rollout.enabledByDefault", false);
EOF
});

    save_screenshot;
    # Close the xterm with root shell
    enter_cmd "killall xterm";
}

# start clean firefox with one suse.com tab, visit pages which trigger pop-up so they will not pop again
# .mozilla is stored as .mozilla_first_run to be reference profile for following tests
sub start_clean_firefox {
    my ($self) = @_;
    mouse_hide(1);

    x11_start_program('xterm');
    # Clean and Start Firefox
    enter_cmd "killall -9 firefox;rm -rf .moz* .config/iced* .cache/iced* .local/share/gnome-shell/extensions/*; firefox /home >firefox.log 2>&1 &";
    wait_still_screen 3;
    assert_screen 'firefox-url-loaded', 90;
    # to avoid stuck trackinfo pop-up, refresh the browser
    $self->firefox_open_url('opensuse.org');
    my $count = 10;
    while ($count--) {
        # workaround for bsc#1046005
        assert_and_click 'firefox_titlebar' if check_screen('firefox_titlebar', 2);
        if (check_screen 'firefox_trackinfo', 3) {
            record_info 'Tracking protection', 'Track info did show up';
            assert_and_click 'firefox_trackinfo';
            last;
        }
        # the needle match area has to be where trackinfo does pop-up
        elsif (check_screen 'firefox-developertool-opensuse') {
            record_info 'Tracking protection', 'Track info pop-up did NOT show up';
            last;
        }
        elsif ($count eq 1) {
            die 'trackinfo pop-up did not match';
        }
        else {
            send_key 'f5';
        }
    }

    # get rid of "Firefox Privacy Notice" page
    wait_still_screen(3);
    if (check_screen 'firefox_privacy_notice') {
        assert_and_click 'firefox_privacy_notice';
    }

    # get rid of the reader & tracking pop-up once, first test should have milestone flag
    $self->firefox_open_url('eu.httpbin.org/html');
    wait_still_screen(3);
    if (check_screen 'firefox_readerview_window') {
        wait_still_screen(3);
        assert_and_click 'firefox_readerview_window';
    }
    # workaround for bsc#1046005
    assert_and_click 'firefox_titlebar' if check_screen('firefox_titlebar', 2);

    # Help
    send_key "alt-h";
    assert_screen 'firefox-help-menu';
    send_key "a";
    assert_screen('firefox-help', 30);
    send_key "esc";

    # restart firefox to trigger default browser pop-up and store .mozilla configuration as default without pop-ups
    $self->restart_firefox('sync && cp -rp .mozilla .mozilla_first_run', 'opensuse.org');
}

sub start_firefox_with_profile {
    my ($self, $url) = @_;
    $url ||= '/home';
    mouse_hide(1);

    x11_start_program('xterm');
    # use mozilla configuration stored with start_clean_firefox
    enter_cmd "killall -9 firefox;rm -rf .mozilla .config/iced* .cache/iced* .local/share/gnome-shell/extensions/*;cp -rp .mozilla_first_run .mozilla";
    # Start Firefox
    enter_cmd "firefox $url >firefox.log 2>&1 &";
    wait_still_screen 2, 4;
    assert_screen 'firefox-url-loaded', 300;
    wait_still_screen 2, 4;
}

sub start_firefox {
    my ($self) = @_;
    mouse_hide(1);

    # Using match_typed parameter on KDE as typing in desktop runner may fail
    x11_start_program('firefox https://html5test.opensuse.org', valid => 0, match_typed => ((check_var('DESKTOP', 'kde')) ? "firefox_url_typed" : ''));
    $self->firefox_check_default;
    $self->firefox_check_popups;
    assert_screen 'firefox-html-test';
}

sub restart_firefox {
    my ($self, $cmd, $url) = @_;
    $url ||= '/home';
    # exit firefox properly
    wait_still_screen 2;
    $self->exit_firefox_common;
    assert_script_run('time wait $(pidof firefox)');
    enter_cmd "$cmd";
    enter_cmd "firefox $url >>firefox.log 2>&1 &";
    $self->firefox_check_default;
    assert_screen 'firefox-url-loaded';
}

sub firefox_check_default {
    # needle can sometimes match before firefox start to load page
    # svirt is special case with TIMEOUT_SCALE=3 which does not affect wait_still_screen
    my $stilltime = get_var('TIMEOUT_SCALE') ? 100 : 10;
    wait_still_screen $stilltime, 100;
    # Set firefox as default browser if asked
    if (check_screen('firefox_default_browser')) {
        wait_screen_change {
            assert_and_click 'firefox_default_browser_yes';
        };
    }
}

# Check whether there are any pop up windows and handle them one by one
sub firefox_check_popups {
    # assert loaded webpage
    assert_screen 'firefox-url-loaded', 300;
    for (1 .. 3) {
        # slow down loop and give firefox time to show pop-up
        sleep 5;
        # check pop-ups
        assert_screen [qw(firefox_trackinfo firefox_readerview_window firefox-launch)];
        # handle the tracking protection pop up
        if (match_has_tag('firefox_trackinfo')) {
            wait_screen_change { assert_and_click 'firefox_trackinfo'; };
        }
        # handle the reader view pop up
        elsif (match_has_tag('firefox_readerview_window')) {
            wait_screen_change { assert_and_click 'firefox_readerview_window'; };
        }

        if (match_has_tag('firefox_trackinfo') or match_has_tag('firefox_readerview_window')) {
            # bsc#1046005 does not seem to affect KDE and as the workaround sometimes results in
            # accidentially moving the firefox window around, skip it.
            if (!check_var("DESKTOP", "kde")) {
                # workaround for bsc#1046005
                assert_and_click 'firefox_titlebar' if check_screen('firefox_titlebar', 2);
            }
        }
    }
}

sub firefox_open_url {
    my ($self, $url) = @_;
    my $counter = 1;
    while (1) {
        # make sure firefox window is focused
        assert_and_click 'firefox_titlebar' if check_screen('firefox_titlebar', 2);
        wait_still_screen 1, 2;
        send_key 'alt-d';
        send_key 'delete';
        send_key 'alt-d';
        send_key 'delete';
        last if check_screen('firefox-empty-bar', 3);
        if ($counter++ > 5) {
            assert_screen('firefox-empty-bar', 0);
            last;    # in case it worked
        }
    }
    enter_cmd_slow "$url";
    assert_screen 'firefox-url-loaded', 180;
}

sub firefox_preferences {
    send_key_until_needlematch 'firefox-edit-menu', 'alt-e', 6, 5;
    send_key_until_needlematch 'firefox-preferences', 'n', 6, 5;
}

sub exit_firefox_common {
    # Exit
    send_key 'ctrl-q';
    wait_still_screen 3, 6;
    send_key_until_needlematch([qw(firefox-save-and-quit xterm-left-open xterm-without-focus)], "alt-f4", 7, 30);
    if (match_has_tag 'firefox-save-and-quit') {
        # confirm "save&quit"
        send_key "ret";
    }
    # wait a sec because xterm-without-focus can match while firefox is being closed
    wait_still_screen 3, 6;
    assert_screen [qw(xterm-left-open xterm-without-focus)];
    if (match_has_tag 'xterm-without-focus') {
        # focus it
        assert_and_click 'xterm-without-focus';
        assert_screen 'xterm-left-open';
    }
}

sub exit_firefox {
    my ($self) = @_;
    $self->exit_firefox_common;
    script_run "cat firefox.log";
    save_screenshot;
    upload_logs "firefox.log";
    enter_cmd "exit";
}

sub start_gnome_settings {
    my $is_sle_12_sp1 = (check_var('DISTRI', 'sle') && check_var('VERSION', '12-SP1'));
    my $workaround_repetitions = 5;
    my $i = $workaround_repetitions;
    my $settings_menu_loaded = 0;

    # the loop is a workaround for SP1: bug in launcher. Sometimes it doesn't react to click
    # The bug will be NOT fixed for SP1.
    do {
        if ($is_sle_12_sp1) {
            if ($i < $workaround_repetitions) {
                record_soft_failure 'bsc#1041175 - The settings menu fails sporadically on SP1';
            }

            send_key 'super';    # if launcher is open, close it (search string will also be removed).
            send_key 'esc';    # close launcher, if it still open
        }
        send_key 'super';
        wait_still_screen;
        type_string 'settings';
        wait_still_screen(3);
        $settings_menu_loaded = check_screen('settings', 0);
        $i--;
    } while ($is_sle_12_sp1 && !$settings_menu_loaded && $i > 0);

    if (!$is_sle_12_sp1 || $settings_menu_loaded) {
        assert_and_click 'settings';
        my $timeout = (is_aarch64) ? '180' : '30';
        assert_screen 'gnome-settings', $timeout;
    }
}

sub unlock_user_settings {
    start_gnome_settings;
    type_string "users";
    assert_screen "settings-users-selected";
    send_key "ret";
    assert_screen "users-settings";
    assert_and_click "Unlock-user-settings";
    assert_screen "authentication-required-user-settings";
    type_password;
    assert_and_click "authenticate";
}

sub setup_evolution_for_ews {
    my ($self, $mailbox, $mail_passwd) = @_;

    mouse_hide(1);

    # Clean and Start Evolution
    x11_start_program("xterm -e \"killall -9 evolution; find ~ -name evolution | xargs rm -rf;\"", valid => 0);
    x11_start_program('evolution', target_match => [qw(evolution-default-client-ask test-evolution-1)]);
    if (match_has_tag "evolution-default-client-ask") {
        assert_and_click "evolution-default-client-agree";
        assert_screen 'test-evolution-1';
    }

    # Follow the wizard to setup mail account
    assert_screen "test-evolution-1";
    send_key "alt-o";
    assert_screen "evolution_wizard-restore-backup";
    send_key_until_needlematch("evolution_wizard-identity", "alt-o", 11);
    wait_screen_change {
        send_key "alt-e";
    };
    type_string "SUSE Test";
    wait_screen_change {
        send_key "alt-a";
    };
    type_string "$mailbox";
    wait_still_screen(2, 2);
    save_screenshot();

    send_key "alt-o";
    assert_screen [qw(evolution_wizard-skip-lookup evolution_wizard-receiving)];
    if (match_has_tag "evolution_wizard-skip-lookup") {
        send_key "alt-s";
        assert_screen 'evolution_wizard-receiving';
    }

    send_key "alt-t";
    wait_still_screen(1);
    send_key "ret";
    send_key_until_needlematch "evolution_wizard-receiving-ews", "up", 11, 3;
    send_key "ret";
    assert_screen "evolution_wizard-ews-prefill";
    send_key "alt-u";
    assert_screen "evolution_mail-auth";
    type_string "$mail_passwd";
    send_key "ret";
    assert_screen "evolution_wizard-ews-oba", 300;
    send_key "alt-o";
    assert_screen "evolution_wizard-receiving-opts";
    assert_and_click "evolution_wizard-ews-enable-gal";
    assert_and_click "evolution_wizard-ews-fetch-abl";
    assert_screen [qw(evolution_wizard-ews-view-gal evolution_mail-auth)], 120;
    if (match_has_tag('evolution_mail-auth')) {
        type_string "$mail_passwd";
        send_key "ret";
        assert_screen "evolution_wizard-ews-view-gal", 120;
    }
    send_key "alt-o";
    assert_screen "evolution_wizard-account-summary";
    send_key "alt-o";
    assert_screen "evolution_wizard-done";
    send_key "alt-a";
    assert_screen "evolution_mail-auth";
    type_string "$mail_passwd";
    send_key "ret";

    # Make all existing mails as read
    assert_screen "evolution_mail-online", 60;
    assert_and_click "evolution_mail-inbox";
    assert_screen "evolution_mail-ready", 60;
    send_key "ctrl-/";
    if (check_screen "evolution_mail-confirm-read") {
        send_key "alt-y";
    }
    assert_screen "evolution_mail-ready", 60;
}

sub evolution_send_message {
    my ($self, $account) = @_;

    my $config = $self->getconfig_emailaccount;
    my $mailbox = $config->{$account}->{mailbox};
    my $mail_passwd = $config->{$account}->{passwd};
    my $mail_subject = $self->get_dated_random_string(4);

    send_key "shift-ctrl-m";
    if (check_screen "evolution_mail-auth", 5) {
        send_key "alt-a";    #disable keyring option
        send_key "alt-p";
        type_string "$mail_passwd";
        wait_still_screen(2, 2);
        send_key "ret";
    }
    assert_screen "evolution_mail-compose-message";
    assert_and_click "evolution_mail-message-to";
    type_string "$mailbox";
    wait_still_screen(2, 2);
    send_key "alt-u";
    wait_still_screen(1);
    type_string "$mail_subject this is a test mail";
    assert_and_click "evolution_mail-message-body";
    type_string "Test email send and receive.";
    send_key "ctrl-ret";
    if (check_screen "evolution_mail_send_mail_dialog", 5) {
        send_key "ret";
    }
    if (check_screen "evolution_mail-auth", 5) {
        send_key "alt-a";    #disable keyring option
        send_key "alt-p";
        type_string "$mail_passwd";
        wait_still_screen(2, 2);
        send_key "ret";
    }

    return $mail_subject;
}

sub pidgin_remove_account {
    wait_screen_change { send_key "ctrl-a" };
    wait_screen_change { send_key "right" };
    wait_screen_change { send_key "ret" };
    wait_screen_change { send_key "alt-d" };
    send_key "alt-d";
}

sub tomboy_logout_and_login {
    wait_screen_change { send_key 'alt-f4' };
    x11_start_program('gnome-session-quit --logout --force', valid => 0);

    # login
    send_key "ret";
    wait_still_screen;
    type_password();
    send_key "ret";
    assert_screen 'generic-desktop';

    # open start note again and take screenshot
    x11_start_program('tomboy note', valid => 0);
}

sub gnote_launch {
    x11_start_program('gnote');
    send_key_until_needlematch 'gnote-start-here-matched', 'down', 6;
}

sub gnote_search_and_close {
    my ($self, $string, $needle) = @_;

    send_key "ctrl-f";
    # The gnote interface is slow. So we can't start immediately searching. We need to wait
    wait_still_screen(2);
    type_string $string;
    assert_screen $needle, 5;

    send_key "ctrl-w";
}

# remove the created new note
sub cleanup_gnote {
    my ($self, $needle) = @_;
    send_key 'esc';    #back to all notes interface
    assert_and_click($needle, button => 'right');
    assert_and_click "delete-new-note";
    assert_and_click "really-delete-note";
    send_key 'ctrl-w';
}

sub gnote_start_with_new_note {
    x11_start_program('gnote');
    send_key "ctrl-n";
    assert_screen 'gnote-new-note', 5;
}

# Configure static ip for NetworkManager on SLED or SLE+WE
sub configure_static_ip_nm {
    my ($self, $ip) = @_;

    x11_start_program('xterm');
    become_root;

    # Dynamic get network interface names
    my $niName = script_output("ls /sys/class/net | grep ^e", type_command => 1);
    chomp $niName;
    # Add new NetworkManager connection with static IP address and default route
    assert_script_run "nmcli connection add type ethernet con-name wired ifname '$niName' ip4 '$ip' gw4 10.0.2.2";
    configure_static_dns(get_host_resolv_conf(), nm_id => 'wired', is_nm => 1);
    assert_script_run "nmcli device disconnect '$niName'";
    assert_script_run "nmcli connection up wired ifname '$niName'";
    enter_cmd "exit";
    wait_screen_change { send_key 'alt-f4' };
}

# Open the firewall port of xdmcp service
sub configure_xdmcp_firewall {
    my ($self) = @_;

    if ($self->firewall eq 'firewalld') {
        assert_script_run 'firewall-cmd --permanent --zone=public --add-port=6000-6010/tcp';
        assert_script_run 'firewall-cmd --permanent --zone=public --add-port=177/udp';
        assert_script_run 'firewall-cmd --reload';
    }
    else {
        assert_script_run 'yast2 firewall services add zone=EXT service=service:xdmcp';
    }
}

sub check_desktop_runner {
    x11_start_program('true', target_match => 'generic-desktop', no_wait => 1);
}

sub disable_key_repeat {
    x11_start_program('xset -r', target_match => 'generic-desktop', no_wait => 1);
}

# Start one of the libreoffice components, close any first-run dialogs
sub libreoffice_start_program {
    my ($self, $program) = @_;
    my %start_program_args;
    $start_program_args{timeout} = 100 if get_var('LIVECD') && check_var('MACHINE', 'uefi-usb');
    x11_start_program($program, %start_program_args);
    if (check_screen('ooffice-tip-of-the-day', 5)) {
        # Unselect "_S_how tips on startup", select "_O_k"
        send_key "alt-s";
        send_key "alt-o";
    }
}

sub start_gnome_tweak_tool {
    my @gnome_tweak_matches = qw(gnome-tweaks gnome-tweak-tool command-not-found);

    send_key "esc";
    x11_start_program('gnome-tweaks', target_match => \@gnome_tweak_matches);

    if (match_has_tag('command-not-found')) {
        # GNOME Tweak tool was renamed to GNOME Tweaks during 3.28 dev branch
        # As the new name yielded a 'command-not-found', start as old command
        send_key 'esc';
        x11_start_program('gnome-tweak-tool');
    }

    if (check_screen('gnome-tweak-extensions-moved')) {
        # GNOME 40 moved extensions out of tweak tool, pops a warning
        assert_and_click('gnome-tweak-extensions-moved');
    }
}

# Since GNOME 40 or later, the 'Input Sources' is no longer in the 'Region & Language' panel
# The 'Input Sources' is in the gnome-control-center 'Keyboard' panel now
# Navigate to the 'Keyboard' panel first and then add the input source that to be tested
sub add_input_resource {
    my ($self, $tag) = @_;

    if (is_sle('<=15-sp3') || is_leap('<=15.3')) {
        x11_start_program "gnome-control-center region", target_match => "g-c-c-region-language";
    }
    else {
        x11_start_program "gnome-control-center keyboard", target_match => "g-c-c-keyboard";
    }

    assert_and_click 'ibus-input-source-add';
    assert_and_click 'ibus-input-language-list';
    type_string $tag;

    assert_and_click "ibus-input-$tag";
    if ($tag eq "japanese") {
        assert_and_dclick 'ibus-input-japanese-kkc';
    }
    elsif ($tag eq "chinese") {
        assert_and_dclick 'ibus-input-chinese-pinyin';
    }
    elsif ($tag eq "korean") {
        assert_and_dclick 'ibus-input-korean-hangul';
    }
    assert_screen "ibus-input-added-$tag";
    send_key 'alt-f4';
    assert_screen 'generic-desktop';
}

sub firefox_print2file_overview {
    my ($self, $file) = @_;

    # Prepare files for firefox printing
    x11_start_program('gnome-terminal');
    if (script_run("test -d ffprint")) {
        assert_script_run "mkdir ffprint";
    }
    script_run "cd ffprint";
    assert_script_run("wget " . autoinst_url . "/data/x11/firefox/$file");

    if ($file eq "horizframetest") {
        assert_script_run("wget " . autoinst_url . "/data/x11/firefox/horizframetest_files.tar.xz");
        assert_script_run("tar xvf horizframetest_files.tar.xz");
    }
    elsif ($file eq "vertframetest") {
        assert_script_run("wget " . autoinst_url . "/data/x11/firefox/vertframetest_files.tar.xz");
        assert_script_run("tar xvf vertframetest_files.tar.xz");
    }
    elsif ($file eq "list") {
        assert_script_run("wget " . autoinst_url . "/data/x11/firefox/list_files.tar.xz");
        assert_script_run("tar xvf list_files.tar.xz");
    }
    send_key "alt-f4";
    $self->start_firefox_with_profile;
    $self->firefox_open_url("/home/$username/ffprint/$file");
    assert_screen("firefox-print-$file-display");
    send_key "ctrl-p";
    assert_and_click("firefox-print-$file-overview");
}

sub firefox_print {
    my ($self, $file) = @_;

    # Click the "Save" button on the print overview page
    assert_and_click("firefox-print2pdf-save");

    # Specify the path and name of output file
    send_key "ctrl-a";
    type_string("/home/$username/ffprint/$file-output.pdf");

    # Click save button on the save to destination page
    assert_and_click("firefox-print-output-save");

    wait_still_screen 5;

    # Close firefox
    send_key "alt-f4";
}

sub verify_firefox_print_output {
    my ($self, $file) = @_;

    # Verify the content and format of output file
    x11_start_program("evince /home/$username/ffprint/$file-output.pdf", target_match => "evince-$file-output-default");
    wait_still_screen 2;
    send_key "alt-f10";    # maximize window
    assert_screen("evince-$file-output-pdf", 5);
    send_key "ctrl-w";    # close evince
}

sub cleanup_firefox_print {
    assert_script_run "rm -rf /home/$username/ffprint/*";
    send_key 'ctrl-d';
    assert_screen 'generic-desktop';
}
1;
