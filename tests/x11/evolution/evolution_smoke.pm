# Evolution tests
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: glib2-tools evolution
# Summary: Case #1503857: Evolution First time launch and setup assistant
# - Cleanup evolution config files and start application
# - Handle evolution first time wizard
# - Register an account using the provided credentials
# - Check for authentication or folder scan attempts
# - Open help and then go to about
# - Send esc to close help
# - Exit evolution
# Maintainer: Zhaocong Jia <zcjia@suse.com>

use base "x11test";
use testapi;
use utils;
use version_utils qw(is_sle is_tumbleweed);
use x11utils;
use serial_terminal 'select_serial_terminal';

sub run {
    my $self = shift;
    my $mail_box = 'nooops_test3@aim.com';
    my $mail_passwd = 'hkiworexcmmeqmzt';

    select_serial_terminal;
    assert_script_run('curl -v -o  /home/bernhard/evolution-backup.tar.gz  ' . data_url('evolution/evolution-backup.tar.gz'), 180);

    select_console 'x11';

    mouse_hide(1);
    turn_off_screensaver;

    assert_screen "generic-desktop";

    $self->start_evolution_from_backupfile($mail_box);
    assert_screen('evolution_mail-auth', 200);
    if (match_has_tag "evolution_mail-auth") {
        send_key "alt-p";
        type_string "$mail_passwd";
        send_key "ret";
    }
    assert_screen('evolution_mail-init-window', 120);
    send_key "super-up" if (match_has_tag "evolution_mail-init-window");
    wait_still_screen(2, 2);
    assert_and_click("evolution_click_inbox");
    wait_still_screen(2, 2);
    assert_and_click 'evolution-select-email', dclick => 1;
    wait_still_screen(2, 2);
    assert_screen("evolution_inbox_email");
    wait_still_screen(2, 2);
    assert_and_click("evolution_open_inbox_mail");
    wait_still_screen(2, 2);
    send_key_until_needlematch('evolution_read_test_message', 'ret', 4, 2);
    # Exit
    send_key "ctrl-w";
    send_key "ctrl-q";
    assert_screen "generic-desktop";
}

1;
