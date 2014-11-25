use base "console_yasttest";
use testapi;

sub run() {
    my $self    = shift;
    my $pkgname = get_var("PACKAGETOINSTALL");

    become_root();
    type_string "PS1=\"# \"\n";

    if ( get_var("UPGRADE") ) {
        # old versions had a different default and we don't necessarly update
        script_run('echo PKGMGR_ACTION_AT_EXIT=summary >> /etc/sysconfig/yast2');
    }

    script_run("/sbin/yast2 sw_single; echo yast2-i-status-\$? > /dev/$serialdev");
    assert_screen 'empty-yast2-sw_single';
    type_string("$pkgname\n");
    sleep 3;
    send_key "spc";    # select for install
    sleep 1;
    assert_screen "package-$pkgname-selected-for-install", 3;
    send_key "alt-a", 1;    # accept
    assert_screen 'yast2-sw_shows_summary', 3;
    send_key "alt-f";
    wait_serial("yast2-i-status-0", 10) || die "yast didn't finish";

    send_key "ctrl-l";                  # clear screen to see that second update does not do any more
    script_run("rpm -e $pkgname && echo '$pkgname removed' > /dev/$serialdev");
    wait_serial("$pkgname removed") || die "$pkgname remove failed";

    script_run("echo mark yast test"); # avoid zpper needle
    script_run("rpm -q $pkgname");
    script_run('exit');
    assert_screen( "yast-package-$pkgname-not-installed", 1 );
}

1;
# vim: set sw=4 et:
