package installstep;
use base "basetest";

use bmwqemu;

# using this as base class means only run when an install is needed
sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$bmwqemu::vars{NOINSTALL} && !$bmwqemu::vars{LIVETEST};
}

sub test_flags() {
    return { 'fatal' => 1 };
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
    } elsif ($ret) {
        send_key "ctrl-alt-f2";
        assert_screen "inst-console";
        if ( !$bmwqemu::vars{NET} ) {
            type_string "cd /proc/sys/net/ipv4/conf\n";
            type_string "for i in *[0-9]; do echo BOOTPROTO=dhcp > /etc/sysconfig/network/ifcfg-\$i; wicked --debug all ifup \$i; done\n";
            type_string "ifconfig -a\n";
            type_string "cat /etc/resolv.conf\n";
        }
        type_string "save_y2logs /tmp/y2logs.tar.bz2\n";
        upload_logs "/tmp/y2logs.tar.bz2";
        save_screnshot();
    }
}

1;
# vim: set sw=4 et:
