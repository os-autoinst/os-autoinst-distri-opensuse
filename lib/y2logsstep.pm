package y2logsstep;
use base "installbasetest";
use testapi;

sub use_wicked() {
    type_string "cd /proc/sys/net/ipv4/conf\n";
    type_string "for i in *[0-9]; do echo BOOTPROTO=dhcp > /etc/sysconfig/network/ifcfg-\$i; wicked --debug all ifup \$i; done\n";
}

sub use_ifconfig() {
    type_string "dhcpcd eth0\n";
}

sub get_ip_address() {
    if ( !get_var('NET') ) {
        if ( get_var('OLD_IFCONFIG') ) {
            use_ifconfig;
        }
        else  {
            use_wicked;
        }
        type_string "ifconfig -a\n";
        type_string "cat /etc/resolv.conf\n";
    }
}

sub get_to_console() {
    my @tags = qw/yast-still-running linuxrc-install-fail linuxrc-repo-not-found/;
    my $ret = check_screen( \@tags, 5 );
    if ($ret && $ret->{needle}->has_tag("linuxrc-repo-not-found")) {
        send_key "ctrl-alt-f9";
        wait_idle;
        assert_screen "inst-console";
        type_string "blkid\n";
        save_screenshot();
        send_key "ctrl-alt-f3";
        wait_idle;
        sleep 1;
        save_screenshot();
    }
    elsif ($ret) {
        send_key "ctrl-alt-f2";
        assert_screen "inst-console";
        get_ip_address;
    }
    else {
        # We ended up somewhere else, still in a phase we consider yast running
        # (e.g. livecdrerboot did not see a grub screen and booted through to an installed system)
        # so we try to perform a login on TTY2 and export yast logs
        send_key "ctrl-alt-f2";
        assert_screen("text-login", 10);
        type_string "root\n";
        sleep 2;
        type_password;
        type_string "\n";
        sleep 1;
    }
}

sub save_upload_y2logs() {
    type_string "save_y2logs /tmp/y2logs.tar.bz2; echo y2logs-saved-\$? > /dev/$serialdev\n";
    $ret = wait_serial 'y2logs-saved-\d+';
    die "failed to save y2logs" unless (defined $ret && $ret =~ /y2logs-saved-0/);
    upload_logs "/tmp/y2logs.tar.bz2";
    save_screenshot();
}

sub post_fail_hook() {
    my $self = shift;
    get_to_console;
    save_upload_y2logs;
}

1;
# vim: set sw=4 et:
