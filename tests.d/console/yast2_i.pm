use base "yaststep";
use bmwqemu;

sub run() {
    my $self    = shift;
    my $pkgname = "sysstat";

    become_root();
    type_string "PS1=\"# \"\n";

    script_run("/sbin/yast2 sw_single; echo yast2-i-status-\$? > /dev/$serialdev");
    assert_screen 'yast2-sw_single';
    type_string("$pkgname\n");
    sleep 3;
    send_key "spc";    # select for install
    sleep 1;
    assert_screen 'test-yast2-i-1', 3;
    send_key "alt-a", 1;    # accept
    assert_screen 'yast2-sw_single-finished', 3;
    send_key "alt-f";
    wait_serial "yast2-i-status-0";

    send_key "ctrl-l";                  # clear screen to see that second update does not do any more
    script_run("rpm -e $pkgname");
    script_run("rpm -q $pkgname");
    script_run('exit');
    assert_screen( "package-$pkgname-not-installed", 1 );
}

1;
# vim: set sw=4 et:
