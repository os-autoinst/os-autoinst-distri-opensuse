# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package windowsbasetest;
use base 'basetest';
use strict;
use warnings;
use testapi;

sub _setup_serial_device {
    type_string '$port = new-Object System.IO.Ports.SerialPort COM1,9600,None,8,one', max_interval => 125;
    wait_screen_change(sub { send_key 'ret' }, 10);
    type_string '$port.open()', max_interval => 125;
    wait_screen_change(sub { send_key 'ret' }, 10);
    type_string '$port.WriteLine("Serial Port has been opened...")', max_interval => 125;
    wait_screen_change(sub { send_key 'ret' }, 10);
    wait_serial 'Serial Port has been opened...';
}

sub use_search_feature {
    my ($self, $string_to_search) = @_;
    return unless ($string_to_search);

    send_key_until_needlematch 'windows-search-bar', 'super-s';
    wait_still_screen stilltime => 2, timeout => 15;
    type_string "$string_to_search ", max_interval => 100, wait_still_screen => 0.5;
}

sub select_windows_in_grub2 {
    return unless (get_var('DUALBOOT'));

    assert_screen "grub-reboot-windows", 125;
    send_key "down" for (1 .. 2);
    send_key "ret";
}

sub open_powershell_as_admin {
    my ($self, %args) = @_;
    send_key_until_needlematch 'quick-features-menu', 'super-x';
    wait_still_screen stilltime => 2, timeout => 15;
    send_key_until_needlematch 'user-acount-ctl-allow-make-changes', 'shift-a';
    assert_and_click 'user-acount-ctl-yes';
    wait_still_screen stilltime => 2, timeout => 15;
    assert_screen 'powershell-as-admin-window', 180;
    assert_and_click 'window-max';
    sleep 3;
    _setup_serial_device unless (exists $args{no_serial});
}

sub run_in_powershell {
    my ($self, %args) = @_;
    my $rc_hash = testapi::hashed_string $args{cmd};

    type_string $args{cmd}, max_interval => 125;

    if (exists $args{code} && (ref $args{code} eq 'CODE')) {
        wait_screen_change(sub { send_key 'ret' }, 10);
        $args{code}->();
    } else {
        type_string ';$port.WriteLine(\'' . $rc_hash . '\' + $?)', max_interval => 125;
        wait_screen_change(sub { send_key 'ret' }, 10);
        wait_serial("${rc_hash}True", timeout => (exists $args{timeout}) ? $args{timeout} : 30) or
          die "Expected string (${rc_hash}True) was not found on serial";
    }

    send_key 'ctrl-l';
}

sub reboot_or_shutdown {
    my ($self, $is_reboot) = @_;
    send_key_until_needlematch 'ms-quick-features', 'super-x';
    wait_screen_change(sub { send_key 'u' }, 10);
    sleep 1;
    wait_screen_change(sub { send_key((!!$is_reboot) ? 'r' : 'u') }, 10);
    save_screenshot;
    assert_shutdown unless ($is_reboot);
}

sub wait_boot_windows {
    # Reset the consoles: there is no user logged in anywhere
    reset_consoles;

    assert_screen 'windows-screensaver',        150;
    send_key_until_needlematch 'windows-login', 'esc';
    type_password;
    send_key 'ret';    # press shutdown button

    assert_screen 'windows-desktop', 120;
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    sleep 30;
    save_screenshot;
}

1;
