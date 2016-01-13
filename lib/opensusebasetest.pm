package opensusebasetest;
use base 'basetest';

use testapi;

# Base class for all openSUSE tests

sub clear_and_verify_console {
    my ($self) = @_;

    script_run 'clear';
    assert_screen('cleared-console');

}

sub post_run_hook {
    my ($self) = @_;
    # overloaded in x11 and console
}

sub export_logs {
    my $self = shift;

    select_console 'root-console';
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

# Set a simple reproducible prompt for easier needle matching without hostname
sub set_standard_prompt {
    $testapi::distri->set_standard_prompt;
}

sub select_bootmenu_option {
    my ($self, $tag, $more) = @_;

    assert_screen "inst-bootmenu", 15;

    # after installation-images 14.210 added a submenu
    if ($more && check_screen "inst-submenu-more", 1) {
        if (get_var('OFW')) {
            send_key_until_needlematch 'inst-onmore', 'up';
        }
        else {
            send_key_until_needlematch('inst-onmore', 'down', 10, 5);
        }
        send_key "ret";
    }
    if (get_var('OFW')) {
        send_key_until_needlematch $tag, 'up';
    }
    else {
        send_key_until_needlematch($tag, 'down', 10, 5);
    }
    send_key "ret";
}

1;
# vim: set sw=4 et:
