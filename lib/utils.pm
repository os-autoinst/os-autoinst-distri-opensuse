package utils;

use base Exporter;
use Exporter;

use strict;

use testapi;

our @EXPORT = qw/unlock_if_encrypted wait_boot clear_console select_kernel/;

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
    my %args            = @_;
    my $bootloader_time = $args{bootloader_time} // 100;
    my $textmode        = $args{textmode};

    if (get_var("OFW")) {
        assert_screen "bootloader-ofw", $bootloader_time;
    }
    else {
        my @tags = ('grub2');
        push @tags, 'bootloader-shim-import-prompt'   if get_var('UEFI');
        push @tags, 'boot-live-' . get_var('DESKTOP') if get_var('LIVETEST');    # LIVETEST won't to do installation and no grub2 menu show up
        check_screen(\@tags, $bootloader_time);
        if (match_has_tag("bootloader-shim-import-prompt")) {
            send_key "down";
            send_key "ret";
            assert_screen "grub2", 15;
        }
        elsif (get_var("LIVETEST")) {
            # prevent if one day booting livesystem is not the first entry of the boot list
            if (!match_has_tag("boot-live-" . get_var("DESKTOP"))) {
                send_key_until_needlematch("boot-live-" . get_var("DESKTOP"), 'down', 10, 5);
            }
            send_key "ret";
        }
        elsif (!match_has_tag("grub2")) {
            # check_screen timeout
            die "needle 'grub2' not found";
        }
    }

    unlock_if_encrypted;

    if ($textmode || check_var('DESKTOP', 'textmode')) {
        assert_screen 'linux-login', 200;
        return;
    }

    mouse_hide();

    if (get_var("NOAUTOLOGIN") || get_var("XDMUSED")) {
        assert_screen 'displaymanager', 200;
        wait_idle;
        if (get_var('DM_NEEDS_USERNAME')) {
            type_string $username;
        }
        if (match_has_tag("sddm")) {
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

# 'ctrl-l' does not get queued up in buffer. If this happens to fast, the
# screen would not be cleared
sub clear_console {
    type_string "clear\n";
}

sub select_kernel {
    my $kernel = shift;

    assert_screen 'grub2', 100;
    send_key 'up';    # stop grub2 countdown
    if (check_screen "grub2-$kernel-selected", 2) {    # if requested kernel is selected continue
        send_key 'ret';
    }
    else {                                             # else go to that kernel thru grub2 advanced options
        send_key_until_needlematch 'grub2-advanced-options', 'down';
        send_key 'ret';
        send_key_until_needlematch "grub2-$kernel-selected", 'down';
        send_key 'ret';
    }
    if (get_var('NOAUTOLOGIN')) {
        my $ret = assert_screen 'displaymanager', 200;
        mouse_hide();
        if (get_var('DM_NEEDS_USERNAME')) {
            type_string $username;
        }
        else {
            send_key 'ret';
            wait_idle;
        }
        type_string "$password";
        send_key 'ret';
    }
}

1;

# vim: sw=4 et
