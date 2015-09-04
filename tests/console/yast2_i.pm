use base "console_yasttest";
use testapi;

sub run() {
    my $self    = shift;
    my $pkgname = get_var('PACKAGETOINSTALLWITHRECOMMENDS', 'powertop');

    become_root();
    type_string "PS1=\"# \"\n";

    assert_script_run "zypper -n in yast2-packager"; # make sure yast2 sw_single module installed

    script_run("/sbin/yast2 sw_single; echo yast2-i-status-\$? > /dev/$serialdev");
    if (check_screen('workaround-bsc924042', 10)) {
        send_key 'alt-o';
        record_soft_failure;
    }
    assert_screen 'empty-yast2-sw_single';

    # Testcase according to https://fate.suse.com/318099
    # TC1: Prerequisite: package -> package-lang
    # Select a certain package (package), check that another (package-lang) gets selected/installed 
    type_string("$pkgname\n");
    sleep 3;
    send_key "spc";    # select for install

    assert_screen "package-$pkgname-and-recommended-selected-for-install", 5;

    # TC2b:Prerequisite: package -> package-lang
    # Given that package is not installed,
    # uncheck Dependencies/Install Recommended Packages,
    # select package, verify that package-lang is NOT selected
    send_key "alt-d"; # Menu "Dependencies"
    assert_screen 'yast2-sw_install_recommended_packages_enabled', 60;
    send_key "alt-r"; # Submenu Install Recommended Packages

    assert_screen "package-$pkgname-only-selected-for-install", 5;
    send_key "alt-a", 1;    # accept

    # Upgrade tests and the old distributions eg. SLE11 doesn't shows the summary
    unless ( get_var("YAST_SW_NO_SUMMARY") ) {
        assert_screen 'yast2-sw_shows_summary', 60;
        send_key "alt-f";
    }
    # yast might take a while on sle11 due to suseconfig
    wait_serial("yast2-i-status-0", 60) || die "yast didn't finish";

    send_key "ctrl-l";                  # clear screen to see that second update does not do any more
    assert_script_run("rpm -e $pkgname");   # erase $pkgname
    script_run("echo mark yast test"); # avoid zpper needle
    script_run("rpm -q $pkgname");
    sleep 2;
    script_run('exit');
    assert_screen( "yast-package-$pkgname-not-installed", 1 );
}

1;
# vim: set sw=4 et:
