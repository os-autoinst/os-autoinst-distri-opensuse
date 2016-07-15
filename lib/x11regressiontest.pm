# Base class for all x11regression test
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package x11regressiontest;
use base "x11test";
use strict;
use warnings;
use LWP::Simple;
use Config::Tiny;
use testapi;
use utils;
use POSIX qw(strftime);

sub test_flags() {
    return {important => 1};
}

# import_pictures helps shotwell to import test pictures into shotwell's library.
sub import_pictures {
    my ($self, $pictures) = @_;

    # Fetch test pictures to ~/Documents
    foreach my $picture (@$pictures) {
        x11_start_program("wget " . autoinst_url . "/data/x11regressions/$picture -O /home/$username/Documents/$picture");
    }

    # Open the dialog 'Import From Folder'
    wait_screen_change {
        send_key "ctrl-i";
    };
    assert_screen 'shotwell-importing';
    send_key "ctrl-l";
    type_string "/home/$username/Documents\n";
    send_key "ret";

    # Choose 'Import in Place'
    if (check_screen 'shotwell-import-prompt') {
        send_key "alt-i";
    }
    assert_screen 'shotwell-imported-tip';
    send_key "ret";
    assert_screen 'shotwell-imported';
}

# clean_shotwell helps to clean shotwell's library then remove the test picture.
sub clean_shotwell() {
    # Clean shotwell's database
    x11_start_program("rm -rf /home/$username/.local/share/shotwell");

    # Remove test pictures
    x11_start_program("rm /home/$username/Documents/shotwell_test.*");
}

# upload libreoffice specified file into /home/$username/Documents
sub upload_libreoffice_specified_file() {

    x11_start_program("xterm");
    assert_script_run("wget " . autoinst_url . "/data/x11regressions/ooo-test-doc-types.tar.bz2 -O /home/$username/Documents/ooo-test-doc-types.tar.bz2");
    wait_still_screen;
    type_string("cd /home/$username/Documents && ls -l");
    send_key "ret";
    wait_screen_change {
        assert_screen("libreoffice-find-tar-file");
        type_string("tar -xjvf ooo-test-doc-types.tar.bz2");
        send_key "ret";
    };
    wait_still_screen;
    send_key "alt-f4";

}

# cleanup libreoffcie specified file from test vm
sub cleanup_libreoffice_specified_file() {

    x11_start_program("xterm");
    assert_script_run("rm -rf /home/$username/Documents/ooo-test-doc-types*");
    wait_still_screen;
    type_string("ls -l /home/$username/Documents");
    send_key "ret";
    wait_screen_change {
        assert_screen("libreoffice-find-no-tar-file");
    };
    wait_still_screen;
    send_key "alt-f4";

}

# cleanup libreoffice recent open file to make sure libreoffice clean
sub cleanup_libreoffice_recent_file() {

    x11_start_program("libreoffice");
    send_key "alt-f";
    send_key "alt-u";
    assert_screen("libreoffice-recent-documents");
    send_key_until_needlematch("libreoffice-clear-list", "down");
    send_key "ret";
    assert_screen("welcome-to-libreoffice");
    send_key "ctrl-q";

}

# check libreoffice dialog windows setting- "gnome dialog" or "libreoffice dialog"
sub check_libreoffice_dialogs() {

    # make sure libreoffice dialog option is disabled status
    send_key "alt-t";
    send_key "alt-o";
    assert_screen("ooffice-tools-options");
    send_key_until_needlematch('libreoffice-options-general', 'down');
    assert_screen("libreoffice-general-dialogs-disabled");
    send_key "alt-o";
    send_key "alt-o";
    assert_screen("libreoffice-gnome-dialogs");
    send_key "alt-c";

    # enable libreoffice dialog
    send_key "alt-t";
    send_key "alt-o";
    assert_screen("libreoffice-options-general");
    send_key "alt-u";
    assert_screen("libreoffice-general-dialogs-enabled");
    send_key "alt-o";
    send_key "alt-o";
    assert_screen("libreoffice-specific-dialogs");
    send_key "alt-c";

    # restore the default setting
    send_key "alt-t";
    send_key "alt-o";
    assert_screen("libreoffice-options-general");
    send_key "alt-u";
    send_key "alt-o";

}

# get email account information for Evolution test cases
sub getconfig_emailaccount {
    my ($self) = @_;
    my $url = "http://jupiter.bej.suse.com/openqa/password.conf";


    my $file = get($url);

    my $config = Config::Tiny->new;
    $config = Config::Tiny->read_string($file);

    return $config;

}

# check and new mail or meeting for Evolution test cases
# It need define seraching key words to serach mail box.

sub check_new_mail_evolution {
    my ($self, $mail_search, $i, $protocol) = @_;
    my $config      = $self->getconfig_emailaccount;
    my $mail_passwd = $config->{$i}->{passwd};
    assert_screen "evolution_mail-online", 240;
    if (check_screen "evolution_mail-auth") {
        if (sle_version_at_least('12-SP2')) {
            send_key "alt-p";
        }
        type_string "$mail_passwd";
        send_key "ret";
    }
    send_key "alt-w";
    send_key "ret";
    send_key_until_needlematch "evolution_mail_show-all", "down", 5, 3;
    send_key "ret";
    send_key "alt-n";
    send_key "ret";
    send_key_until_needlematch "evolution_mail_show-allcount", "down", 5, 3;
    send_key "ret";
    send_key "alt-c";
    type_string "$mail_search";
    send_key "ret";
    assert_and_click "evolution_meeting-view-new";
    send_key "ret";
    assert_screen "evolution_mail_open_mail";
    send_key "ctrl-w";    # close the mail
    save_screenshot();

    # Delete the message and expunge the deleted item if not used POP3
    if ($protocol != "POP") {
        send_key "ctrl-e";
        if (check_screen "evolution_mail-expunge") {
            send_key "alt-e";
        }
        assert_screen "evolution_mail-ready";
    }
}

# get a random string with followed by date, it used in evolution case to get a unique email title.
sub my_random_str {
    my ($self, $length) = @_;
    my @char_source = ('A' .. 'Z');
    my $ret_string = (strftime "%F", localtime) . "-";
    for (my $i = 1; $i <= $length; $i++) {
        $ret_string .= $char_source[int(rand($#char_source + 1))];
    }
    return $ret_string;
}

#send meeting request by Evolution test cases
sub send_meeting_request {

    my ($self, $sender, $receiver, $mail_subject) = @_;
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
    type_string "$mail_subject this is a evolution test meeting";
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
    assert_screen [qw/evolution_mail-save_meeting_dialog evolution_mail-send_meeting_dialog evolution_mail-meeting_error_handle evolution_mail-max-window/];
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


1;
# vim: set sw=4 et:
