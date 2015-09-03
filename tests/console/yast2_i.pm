use base "console_yasttest";
use testapi;

sub run() {
    my $self    = shift;
    my $pkgname     = get_var("PACKAGETOINSTALL_RECOMMENDER", "yast2-nfs-client");
    my $recommended = get_var("PACKAGETOINSTALL_RECOMMENDED", "nfs-client");

    become_root();
    type_string "PS1=\"# \"\n";

    assert_script_run "zypper -n rm $pkgname $recommended";

    assert_script_run "zypper -n in yast2-packager"; # make sure yast2 sw_single module installed

    script_run("/sbin/yast2 sw_single; echo yast2-i-status-\$? > /dev/$serialdev");
    if (check_screen('workaround-bsc924042', 10)) {
        send_key 'alt-o';
        record_soft_failure;
    }
    assert_screen 'empty-yast2-sw_single';

    # Testcase according to https://fate.suse.com/318099
    # UC1:
    # Select a certain package, check that another gets selected/installed
    type_string("$pkgname\n");
    sleep 3;
    send_key "spc";    # select for install
    assert_screen "$pkgname-selected-for-install", 5;

    send_key "alt-p"; # go to search box again
    for ( 1 .. length($pkgname) ) { send_key "backspace" }
    type_string("$recommended\n");
    assert_screen "$recommended-selected-for-install", 10;

    # UC2b:
    # Given that package is not installed,
    # uncheck Dependencies/Install Recommended Packages,
    # select the package, verify that recommended package is NOT selected
    send_key "alt-d"; # Menu "Dependencies"
    assert_screen 'yast2-sw_install_recommended_packages_enabled', 60;
    send_key "alt-r"; # Submenu Install Recommended Packages

    assert_screen "$recommended-not-selected-for-install", 5;
    send_key "alt-p"; # go to search box again
    for ( 1 .. length($recommended) ) { send_key "backspace" }
    type_string("$pkgname\n");
    assert_screen "$pkgname-selected-for-install", 10;

    send_key "alt-a", 1;    # accept
    # Upgrade tests and the old distributions eg. SLE11 doesn't shows the summary
    unless ( get_var("YAST_SW_NO_SUMMARY") ) {
        assert_screen 'yast2-sw_shows_summary', 60;
        send_key "alt-f";
    }
    # yast might take a while on sle11 due to suseconfig
    wait_serial("yast2-i-status-0", 60) || die "yast didn't finish";

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
