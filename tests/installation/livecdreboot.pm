use strict;
use base "y2logsstep";
use testapi;
use bmwqemu ();

sub run() {
    my $self = shift;
    # NET isos are slow to install
    my $timeout = 2000;

    # workaround for yast popups
    my @tags = qw/rebootnow/;
    if (get_var("UPGRADE")) {
        push(@tags, "ERROR-removing-package");
        $timeout = 5500; # upgrades are slower
    }
    while (1) {
        my $ret = assert_screen \@tags, $timeout;

        if ( $ret->{needle}->has_tag("popup-warning") ) {
            record_soft_failure;
            bmwqemu::diag "warning popup caused dent";
            send_key "ret";
            pop @tags;
            next;
        }
        # can happen multiple times
        if ( $ret->{needle}->has_tag("ERROR-removing-package") ) {
            record_soft_failure;
            send_key 'alt-d';
            assert_screen 'ERROR-removing-package-details';
            send_key 'alt-i';
            assert_screen 'ERROR-removing-package-warning';
            send_key 'alt-o';
            next;
        }
        last;
    }

    if ( get_var("LIVECD") ) {

        # LiveCD needs confirmation for reboot
        send_key $cmd{"rebootnow"};
    }
    else {
        send_key 'ret';
    }

    # XXX old stuff
    #		if(get_var("XDEBUG") && assert_screen "the-system-will-reboot-now", 3000) {
    #			send_key "alt-s";
    #			send_key "ctrl-alt-f2";
    #			if(!get_var("NET")) {
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
    #		if(get_var("UPGRADE")) {
    #			send_key "alt-n"; # ignore repos dialog
    #			wait_still_screen(6,60);
    #		}

    # Await a grub screen for 30s, if seen hit ENTER (in case we did not wait long enough, the 'grub timeout' would
    # pass and still perform the boot; so we want a value short enough to not wait forever if grub does not appear,
    # yet long enough to make sense to even have the test.
    my $ret = check_screen "grub2", 30;
    if ( defined($ret) ) {
        send_key "ret";    # avoid timeout for booting to HDD
    }
}

1;
# vim: set sw=4 et:
