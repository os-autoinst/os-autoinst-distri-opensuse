package opensusebasetest;
use base 'basetest';

use testapi;

# Base class for all openSUSE tests

sub clear_and_verify_console {
    my ($self) = @_;

    send_key "ctrl-l";
    assert_screen('cleared-console');

}

sub post_run_hook {
    my ($self) = @_;
    # overloaded in x11 and console
}

sub export_logs {
    my $self = shift;

    send_key "ctrl-alt-f2";
    assert_screen("text-login", 10);
    type_string "root\n";
    sleep 2;
    type_password;
    type_string "\n";
    sleep 1;

    save_screenshot;

    type_string "cat /home/*/.xsession-errors* > /tmp/XSE\n";
    upload_logs "/tmp/XSE";
    save_screenshot;

    type_string "journalctl -b > /tmp/journal\n";
    upload_logs "/tmp/journal";
    save_screenshot;

    type_string "cat /var/log/X* > /tmp/Xlogs\n";
    upload_logs "/tmp/Xlogs";
    save_screenshot;

    type_string "ps axf > /tmp/psaxf.log\n";
    upload_logs "/tmp/psaxf.log";
    save_screenshot;

    type_string "systemctl list-unit-files > /tmp/systemctl_unit-files.log\n";
    upload_logs "/tmp/systemctl_unit-files.log";
    type_string "systemctl status > /tmp/systemctl_status.log\n";
    upload_logs "/tmp/systemctl_status.log";
    type_string "systemctl > /tmp/systemctl.log\n";
    upload_logs "/tmp/systemctl.log";
    save_screenshot;
}

sub export_captured_audio {
    my $self = shift;

    upload_logs ref($self)."-captured.wav";
}

1;
# vim: set sw=4 et:
