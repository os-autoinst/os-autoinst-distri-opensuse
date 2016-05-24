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

sub save_and_upload_log {
    my ($cmd, $file, $args) = @_;
    script_run "$cmd > $file";
    upload_logs $file;
    save_screenshot if $args->{screenshot};
}

sub export_logs {
    my $self = shift;

    select_console 'root-console';
    save_screenshot;

    save_and_upload_log('cat /home/*/.xsession-errors*', '/tmp/XSE.log',     {screenshot => 1});
    save_and_upload_log('journalctl -b',                 '/tmp/journal.log', {screenshot => 1});
    save_and_upload_log('cat /var/log/X*',               '/tmp/Xlogs.log',   {screenshot => 1});
    save_and_upload_log('ps axf',                        '/tmp/psaxf.log',   {screenshot => 1});

    save_and_upload_log('systemctl list-unit-files', '/tmp/systemctl_unit-files.log');
    save_and_upload_log('systemctl status',          '/tmp/systemctl_status.log');
    save_and_upload_log('systemctl',                 '/tmp/systemctl.log', {screenshot => 1});
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
