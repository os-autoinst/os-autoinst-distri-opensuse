use strict;
use base "y2logsstep";
use bmwqemu;

sub run() {
    my $self = shift;

    # workaround for yast popups
    my @tags = qw/rebootnow/;
    if ($vars{UPGRADE}) {
        push(@tags, "ERROR-removing-package");
    }
    while (1) {
        my $ret = assert_screen \@tags, 2000;    # NET isos and UPGRADE are slow to install

        if ( $ret->{needle}->has_tag("popup-warning") ) {
            ++$self->{dents};
            diag "warning popup caused dent";
            send_key "ret";
            pop @tags;
            next;
        }
        # can happen multiple times
        if ( $ret->{needle}->has_tag("ERROR-removing-package") ) {
            ++$self->{dents};
            send_key 'alt-d';
            assert_screen 'ERROR-removing-package-details';
            send_key 'alt-i';
            assert_screen 'ERROR-removing-package-warning';
            send_key 'alt-o';
            next;
        }
        last;
    }

    if ( $vars{LIVECD} ) {

        # LiveCD needs confirmation for reboot
        send_key $cmd{"rebootnow"};
    }

    # XXX old stuff
    #		if($vars{XDEBUG} && assert_screen "the-system-will-reboot-now", 3000) {
    #			send_key "alt-s";
    #			send_key "ctrl-alt-f2";
    #			if(!$vars{NET}) {
    #				script_run "dhcpcd eth0";
    #				#ifconfig eth0 10.0.2.15
    #				#route add default gw 10.0.2.2
    #				sleep 20;
    #			}
    #			script_run "mount /dev/vda2 /mnt";
    #			script_run "chroot /mnt";
    #			script_run "echo nameserver 213.133.99.99 > /etc/resolv.conf";
    #			script_run "wget www3.zq1.de/bernhard/linux/xdebug";
    #			script_run "sh -x xdebug";
    #			sleep 99;
    #			send_key "ctrl-d";
    #			script_run "umount /mnt";
    #			wait_idle;
    #			sleep 20;
    #			send_key "ctrl-alt-f7";
    #			sleep 5;
    #			send_key "alt-o";
    #		}
    #		if($vars{UPGRADE}) {
    #			send_key "alt-n"; # ignore repos dialog
    #			waitstillimage(6,60);
    #		}

    # meaning of this needle is unclear. It's used in grub as well as
    # 2nd stage automatic configuration. And then ere is also
    # reboot_after_install from 800_reboot_after_install.pm
    # should assert_screen wait for all three at the same time and then have only check_screen afterwards?
    my $ret;
    for (my $counter = 20; $counter > 0; $counter--) {
        $ret = check_screen "grub2", 3;
        if ( defined($ret) ) {
            send_key "ret";    # avoid timeout for booting to HDD
            last;
        }
    }
    # report the failure
    unless ( defined($ret) ) {
        assert_screen "grub2", 1;
    }
}

1;
# vim: set sw=4 et:
