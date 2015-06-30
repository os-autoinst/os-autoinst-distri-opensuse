#!/usr/bin/perl -w

package utils;

use base Exporter;
use Exporter;

use strict;

use testapi;

our @EXPORT = qw/wait_reboot unlock_if_encrypted/;

sub unlock_if_encrypted {

    return unless get_var("ENCRYPT");

    assert_screen("encrypted-disk-password-prompt", 200);
    type_password;    # enter PW at boot
    send_key "ret";
}

sub wait_reboot {
    if ( get_var("OFW") ) {
        assert_screen "bootloader-ofw", 100;
    }
    else {
        assert_screen "grub2", 100;    # wait until reboot
    }

    unlock_if_encrypted;

    if (check_var('DESKTOP', 'textmode')) {
        assert_screen 'linux-login', 200;
        return;
    }

    mouse_hide();

    if ( get_var("NOAUTOLOGIN") || get_var("XDMUSED") ) {
        my $ret = assert_screen 'displaymanager', 200;
        wait_idle;
        if ( get_var('DM_NEEDS_USERNAME') ) {
            type_string $username;
        }
        if ( $ret->{needle}->has_tag("sddm") ) {
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
