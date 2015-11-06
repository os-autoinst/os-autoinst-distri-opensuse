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
        $timeout = 5500;    # upgrades are slower
    }
    while (1) {
        my $ret = assert_screen \@tags, $timeout;

        if ($ret->{needle}->has_tag("popup-warning")) {
            record_soft_failure;
            bmwqemu::diag "warning popup caused dent";
            send_key "ret";
            pop @tags;
            next;
        }
        # can happen multiple times
        if ($ret->{needle}->has_tag("ERROR-removing-package")) {
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

    send_key 'alt-s';    # Stop the reboot countdown

    send_key "ctrl-alt-f2";
    if (get_var("LIVECD")) {
        # LIVE CDa do not run inst-consoles as started by inst-linux (it's regular live run, auto-starting yast live installer)
        assert_screen "text-login", 10;
        # login as root, who does not have a password on Live-CDs
        type_string "root\n";
        sleep 1;
    }
    else {
        assert_screen "inst-console";
    }

    $self->get_ip_address();
    $self->save_upload_y2logs();

    if (check_var('VIDEOMODE', 'text')) {
        send_key 'ctrl-alt-f1';    # get back to YaST
    }
    else {
        send_key 'ctrl-alt-f7';    # get back to YaST
    }

    assert_screen 'rebootnow';

    if (get_var("LIVECD")) {

        # LiveCD needs confirmation for reboot
        send_key $cmd{"rebootnow"};
    }
    else {
        if (check_var('BACKEND', 's390x')) {
            deactivate_console('ctrl-alt-f2');
        }
        send_key 'alt-o';
        if (check_var('BACKEND', 's390x')) {
            deactivate_console("installation");    #Not sure if this is the right place, but this is the last time s390x needs the UI
            select_console('bootloader');
        }
    }

    # XXX old stuff
    #          if(get_var("XDEBUG") && assert_screen "the-system-will-reboot-now", 3000) {
    #                  send_key "alt-s";
    #                  send_key "ctrl-alt-f2";
    #                  if(!get_var("NET")) {
    #                          script_run "dhcpcd eth0";
    #                          #ifconfig eth0 10.0.2.15
    #                          #route add default gw 10.0.2.2
    #                          sleep 20;
    #                  }
    #                  script_run "mount /dev/vda2 /mnt";
    #                  script_run "chroot /mnt";
    #                  script_run "echo nameserver 213.133.99.99 > /etc/resolv.conf";
    #                  script_run "wget www3.zq1.de/bernhard/linux/xdebug";
    #                  script_run "sh -x xdebug";
    #                  sleep 99;
    #                  send_key "ctrl-d";
    #                  script_run "umount /mnt";
    #                  wait_idle;
    #                  sleep 20;
    #                  send_key "ctrl-alt-f7";
    #                  sleep 5;
    #                  send_key "alt-o";
    #          }
    #          if(get_var("UPGRADE")) {
    #                  send_key "alt-n"; # ignore repos dialog
    #                  wait_still_screen(6,60);
    #          }

    # Await a grub screen for 30s, if seen hit ENTER (in case we did not wait long enough, the 'grub timeout' would
    # pass and still perform the boot; so we want a value short enough to not wait forever if grub does not appear,
    # yet long enough to make sense to even have the test.
    my $ret = check_screen "grub2", 30;
    if (defined($ret)) {
        if (get_var("XEN")) {
            send_key_until_needlematch("bootmenu-xen-kernel", 'down', 10, 5);
        }
        send_key "ret";    # avoid timeout for booting to HDD
    }
}

1;
# vim: set sw=4 et:
