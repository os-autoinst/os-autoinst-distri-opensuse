use base "console_yasttest";
use testapi;

sub start_yast {
    my $env = shift || '';

    script_run("$env /sbin/yast2 sw_single; echo yast2-i-status-\$? > /dev/$serialdev");
    if (check_screen('workaround-bsc924042', 10)) {
        send_key 'alt-o';
        record_soft_failure;
    }
    assert_screen 'empty-yast2-sw_single';

    send_key "alt-m", 1; # search mode
    send_key_until_needlematch 'yast2-sw_search_exact_match', 'down', 20;

    send_key "ret", 1;
    send_key "alt-p"; # back to search textentry
}

sub end_yast() {
    # Upgrade tests and the old distributions eg. SLE11 doesn't show the summary
    unless ( get_var("YAST_SW_NO_SUMMARY") ) {
        assert_screen 'yast2-sw_shows_summary', 60;
        send_key "alt-f";
    }

    # yast might take a while on sle11 due to suseconfig
    wait_serial("yast2-i-status-0", 60) || die "yast didn't finish";
}

sub run() {
    my $self    = shift;
    my $pkgname = 'mc';

    become_root();
    type_string "PS1=\"# \"\n";

    assert_script_run "zypper -n in yast2-packager"; # make sure yast2 sw_single module installed

    start_yast;

    # Testcase according to https://fate.suse.com/318099
    # TC1: Prerequisite: mc -> mc-lang
    # Select a certain package (mc), check that another (mc-lang) gets selected/installed 
    type_string("$pkgname\n");
    wait_idle 3;
    send_key "spc";    # select for install

    assert_screen "package-$pkgname-selected-for-install", 5;
    send_key "alt-a", 1;    # accept

    assert_screen 'yast2-sw_autochange_mc-lang', 60;

    # TC2b:Prerequisite: mc -> mc-lang
    # Given that mc is not installed,
    # uncheck Dependencies/Install Recommended Packages,
    # select mc, verify that mc-lang is NOT selected
    send_key "alt-c", 1 ; # Cancel autochange dialog
    send_key "alt-d"; # Menu "Dependencies"

    assert_screen 'yast2-sw_install_recommended_packages_enabled', 60;

    send_key "alt-r"; # Submenu Install Recommended Packages

    # go back to packlist
    send_key_until_needlematch "package-$pkgname-selected-for-install", "tab", 20;

    send_key "alt-a", 1; # accept

    assert_screen 'yast2-sw_autochange_no_mc-lang', 60;
    send_key "alt-o"; # Ok
    end_yast();

#    This testcase is disabled because we consider it not just package manager
#    but more libzypp-related:
#
#    # TC4: Prerequisite: modalias(dmi:*svnDell*) -> biosdevname
#    # ensure biosdevname is not installed
#    # fake modalias
#    # run the command
#    # check biosdevname is selected/installed 
#    start_yast("ZYPP_MODALIAS_SYSFS=/home/$username/data/modaliases");
#
#    $pkgname = "biosdevname";
#    type_string("$pkgname\n");
#    assert_screen "package-$pkgname-selected-for-install", 5;
#
#    # Quit yast without installing.
#    send_key "f9";
#    wait_idle 1;
#    send_key "alt-y";
#
#    end_yast();

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
