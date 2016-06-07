package opensusebasetest;
use base 'basetest';

use testapi;
use utils;
use mm_network;
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

sub export_wicked_logs {
    my $self = shift;

    # https://en.opensuse.org/openSUSE:Bugreport_wicked
    type_string "systemctl status wickedd.service\n";
    type_string "echo `wicked show all |cut -d ' ' -f 1` END | tee /dev/$serialdev\n";
    my $iflist = wait_serial("END", 10);
    $iflist =~ s/\bEND\b//g;
    $iflist =~ s/\blo\b//g;
    $iflist =~ s/^\s*//g;
    $iflist =~ s/\s*$//g;

    my $up = 1;
    for my $if (split(/\s+/, $iflist)) {
        type_string "wicked show '$if' |head -n1|awk '{print\$2}'| tee /dev/$serialdev\n";
        $up = 0 if !wait_serial("up", 10);
    }
    if (!$up) {
        type_string "mkdir /tmp/wicked\n";
        # enable debugging
        type_string "perl -i -lpe 's{^(WICKED_DEBUG)=.*}{\$1=\"all\"};s{^(WICKED_LOG_LEVEL)=.*}{\$1=\"debug\"}' /etc/sysconfig/network/config\n";
        type_string "egrep \"WICKED_DEBUG|WICKED_LOG_LEVEL\" /etc/sysconfig/network/config\n";
        # restart the daemons
        type_string "systemctl restart wickedd\n";
        save_screenshot;
        # reapply the config
        type_string "wicked --debug all ifup all\n";
        save_screenshot;
        # collect the configuration
        type_string "wicked show-config > /tmp/wicked/config-dump.log\n";
        sleep 5;
        # collect the status
        type_string "wicked ifstatus --verbose all > /tmp/wicked/status.log\n";
        type_string "journalctl -b -o short-precise > /tmp/wicked/wicked.log\n";
        type_string "ip addr show > /tmp/wicked/ip_addr.log\n";
        type_string "ip route show table all > /tmp/wicked/routes.log\n";
        # collect network information
        type_string "hwinfo --netcard > /tmp/wicked/hwinfo-netcard.log\n";
        # setup static network, if network interface is down, to be able upload logs.
        configure_default_gateway;
        configure_static_ip('10.0.2.1/24');
        configure_static_dns(get_host_resolv_conf());
        type_string "tar -czf /tmp/wicked_logs.tgz /etc/sysconfig/network /tmp/wicked\n";
        upload_logs "/tmp/wicked_logs.tgz";
        save_screenshot;
    }
}

sub export_logs {
    my $self = shift;

    select_console 'root-console';
    save_screenshot;

    # check if wicked is installed and turn on debug, get all needed wicked logs if network interface is down
    my $wicked_installed = script_run 'rpm -q wicked';
    export_wicked_logs if $wicked_installed;

    save_and_upload_log('cat /proc/loadavg', '/tmp/loadavg',     {screenshot => 1});
    save_and_upload_log('journalctl -b',     '/tmp/journal.log', {screenshot => 1});
    save_and_upload_log('ps axf',            '/tmp/psaxf.log',   {screenshot => 1});

    # check whether xorg logs is exists in user's home, if yes, upload xorg logs from user's
    # home instead of /var/log
    script_run "test -d /home/*/.local/share/xorg ; echo user-xlog-path-\$? > /dev/$serialdev", 0;
    if (wait_serial("user-xlog-path-0", 10)) {
        save_and_upload_log('cat /home/*/.local/share/xorg/X*', '/tmp/Xlogs.log', {screenshot => 1});
    }
    else {
        save_and_upload_log('cat /var/log/X*', '/tmp/Xlogs.log', {screenshot => 1});
    }

    # do not upload empty .xsession-errors
    script_run "xsefiles=(/home/*/.xsession-errors*); for file in \${xsefiles[@]}; do if [ -s \$file ]; then echo xsefile-valid > /dev/$serialdev; fi; done", 0;
    if (wait_serial("xsefile-valid", 10)) {
        save_and_upload_log('cat /home/*/.xsession-errors*', '/tmp/XSE.log', {screenshot => 1});
    }

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
