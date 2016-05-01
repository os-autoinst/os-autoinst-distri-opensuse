package opensusebasetest;
use base 'basetest';

use testapi;
use utils;
use strict;

# Base class for all openSUSE tests


# Additional to backend testapi 'clear-console' we do a needle match to ensure
# continuation only after verification
sub clear_and_verify_console {
    my ($self) = @_;

    clear_console;
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

    script_run "cat /home/*/.xsession-errors* > /tmp/XSE.log";
    upload_logs "/tmp/XSE.log";
    save_screenshot;

    script_run "journalctl -b > /tmp/journal.log";
    upload_logs "/tmp/journal.log";
    save_screenshot;

    script_run "cat /var/log/X* > /tmp/Xlogs.log";
    upload_logs "/tmp/Xlogs.log";
    save_screenshot;

    script_run "ps axf > /tmp/psaxf.log";
    upload_logs "/tmp/psaxf.log";
    save_screenshot;

    script_run "systemctl list-unit-files > /tmp/systemctl_unit-files.log";
    upload_logs "/tmp/systemctl_unit-files.log";
    script_run "systemctl status > /tmp/systemctl_status.log";
    upload_logs "/tmp/systemctl_status.log";
    script_run "systemctl > /tmp/systemctl.log";
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
