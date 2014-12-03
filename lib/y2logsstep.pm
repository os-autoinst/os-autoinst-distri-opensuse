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

sub post_fail_hook() {
    my $self = shift;
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
        type_string "save_y2logs /tmp/y2logs.tar.bz2\n";
        upload_logs "/tmp/y2logs.tar.bz2";
        save_screenshot();
    }
}

1;
# vim: set sw=4 et:
