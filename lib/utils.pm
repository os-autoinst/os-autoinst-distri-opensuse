package utils;

use base Exporter;
use Exporter;

use strict;

use testapi;

our @EXPORT = qw/
  check_console_font
  clear_console
  handle_kwallet
  is_jeos
  select_kernel
  type_string_slow
  type_string_very_slow
  unlock_if_encrypted
  wait_boot
  prepare_system_reboot
  get_netboot_mirror
  zypper_call
  fully_patch_system
  /;


# USB kbd in raw mode is rather slow and QEMU only buffers 16 bytes, so
# we need to type very slowly to not lose keypresses.

# arbitrary slow typing speed for bootloader prompt when not yet scrolling
use constant SLOW_TYPING_SPEED => 13;

# type even slower towards the end to ensure no keybuffer overflow even
# when scrolling within the boot command line to prevent character
# mangling
use constant VERY_SLOW_TYPING_SPEED => 4;

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
    # reconnect s390
    elsif (check_var('ARCH', 's390x')) {
        if (check_var('BACKEND', 's390x')) {

            console('x3270')->expect_3270(
                output_delim => qr/Welcome to SUSE Linux Enterprise Server/,
                timeout      => 300
            );

            # give the system time to have routes up
            # and start serial grab again
            sleep 30;
            reset_consoles;
            select_console('iucvconn');
        }
        else {
            wait_serial("Welcome to SUSE Linux Enterprise Server");
        }

        # on z/(K)VM we need to re-select a console
        if ($textmode || check_var('DESKTOP', 'textmode')) {
            select_console('root-console');
            reset_consoles;
        }
        else {
            select_console('x11');
            reset_consoles;
        }
        return;
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
        reset_consoles;
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

    # Reset the consoles after the reboot: there is no user logged in anywhere
    reset_consoles;
}

# 'ctrl-l' does not get queued up in buffer. If this happens to fast, the
# screen would not be cleared
sub clear_console {
    type_string "clear\n";
}

# in some backends we need to prepare the reboot/shutdown
sub prepare_system_reboot {
    if (check_var('BACKEND', 's390x')) {
        console('iucvconn')->kill_ssh;
    }
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

# 13.2, Leap 42.1, SLE12 GA&SP1 have problems with setting up the
# console font, we need to call systemd-vconsole-setup to workaround
# that
sub check_console_font {
    select_console('root-console');
    # Ensure the echo of input actually happened by using assert_script_run
    assert_script_run "echo Jeder wackere Bayer vertilgt bequem zwo Pfund Kalbshaxen. 0123456789";
    if (check_screen "broken-console-font", 5) {
        assert_script_run("/usr/lib/systemd/systemd-vconsole-setup");
    }
}

sub is_jeos() {
    return get_var('FLAVOR', '') =~ /^JeOS/;
}

sub type_string_slow {
    my ($string) = @_;

    type_string $string, SLOW_TYPING_SPEED;
}

sub type_string_very_slow {
    my ($string) = @_;

    type_string $string, VERY_SLOW_TYPING_SPEED;

    # the bootloader prompt line is very delicate with typing especially when
    # scrolling. We are typing very slow but this could still pose problems
    # when the worker host is utilized so better wait until the string is
    # displayed before continuing
    wait_still_screen 1;
}

sub handle_kwallet {
    my ($enable) = @_;
    # enable = 1 as enable kwallet, archive kwallet enabling process
    # enable = 0 as disable kwallet, just close the popup dialog
    $enable //= 0;    # default is disable kwallet

    return unless (check_var('DESKTOP', 'kde'));

    if (check_screen("kwallet-wizard", 5)) {
        if ($enable) {
            send_key "alt-n";
            sleep 2;
            send_key "spc";
            sleep 2;
            send_key "down";    # use traditional way
            type_password;
            send_key "tab";
            sleep 1;
            type_password;
            send_key "alt-f";

            assert_screen "kwallet-opening", 5;
            type_password;
            send_key "ret", 1;
        }
        else {
            send_key "alt-f4", 1;
        }
    }
}

sub get_netboot_mirror {
    my $m_protocol = get_var('INSTALL_SOURCE', 'http');
    return get_var('MIRROR_' . uc($m_protocol));
}

sub zypper_call {
    my $command = shift;
    my $timeout = shift || 700;
    my $str     = bmwqemu::hashed_string("ZN$command");

    script_run("zypper -n $command; echo $str-\$?- > /dev/$serialdev", 0);

    my $ret = wait_serial(qr/$str-\d+-/, $timeout);
    if ($ret) {
        my ($ret_code) = $ret =~ /$str-(\d+)/;
        return $ret_code;
    }
    die "zypper doesn't return exitcode";
}

sub fully_patch_system {
    # first run, possible update of packager -- exit code 103
    my $ret = zypper_call('patch --with-interactive -l');
    die "zypper failed with code $ret" unless grep { $_ == $ret } (0, 102, 103);
    # second run, full system update
    $ret = zypper_call('patch --with-interactive -l', 2500);
    die "zypper failed with code $ret" unless grep { $_ == $ret } (0, 102);
}
1;

# vim: sw=4 et
