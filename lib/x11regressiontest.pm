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
use LWP::Simple;
use Config::Tiny;
use testapi;

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
1;
# vim: set sw=4 et:
