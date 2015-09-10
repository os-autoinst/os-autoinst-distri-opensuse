#!/usr/bin/perl -w

package utils;

use base Exporter;
use Exporter;

use strict;

use testapi;

our @EXPORT = qw/wait_boot unlock_if_encrypted/;

sub unlock_if_encrypted {

    return unless get_var("ENCRYPT");

    assert_screen("encrypted-disk-password-prompt", 200);
    type_password;    # enter PW at boot
    send_key "ret";
}

# makes sure bootloader appears and then boots to desktop resp text
# mode. Handles unlocking encrypted disk if needed.
# arguments: bootloader_time => seconds # now long to wait for bootloader to appear
sub wait_boot {
    my %args = @_;
    my $bootloader_time = $args{bootloader_time} // 100;

    if ( get_var("OFW") ) {
        assert_screen "bootloader-ofw", $bootloader_time;
    }
    else {
        check_screen([qw/bootloader-shim-import-prompt grub2/], $bootloader_time);
        if (match_has_tag("bootloader-shim-import-prompt")) {
            send_key "down";
            send_key "ret";
            $bootloader_time = 15;
        }

        assert_screen "grub2", $bootloader_time;
    }

    unlock_if_encrypted;

    if (check_var('DESKTOP', 'textmode')) {
        assert_screen 'linux-login', 200;
        return;
    }

    mouse_hide();

    if ( get_var("NOAUTOLOGIN") || get_var("XDMUSED") ) {
        assert_screen 'displaymanager', 200;
        wait_idle;
        if ( get_var('DM_NEEDS_USERNAME') ) {
            type_string $username;
        }
        if ( match_has_tag("sddm") ) {
            # make sure choose plasma5 session
            assert_and_click "sddm-sessions-list";
            assert_and_click "sddm-sessions-plasma5";
            assert_and_click "sddm-password-input";
            type_string "$password";
            send_key "ret";
        }
        else {
            # log in
            #assert_screen "dm-password-input", 10;
            send_key "ret";
            wait_idle;
        }
        type_string $password. "\n";
    }

    assert_screen 'generic-desktop', 300;
    mouse_hide(1);
}

1;

# vim: sw=4 et
