# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Hostname in YaST Installer is set properly
#    PR#11456 (FATE#319639)
#
#    This test makes sure that correct hostname is set during installation.
#    Basicly if no hostname comes from environment (DHCP), it's set to
#    "install".
#
#    Test cases covered (and to be implemented in openQA):
#
#    Test1
#    Start installation without additional param on kernel cmd line.
#    Check whether hostname 'install' is set
#    /usr/share/openqa/script/clone_job.pl --from http://openqa.suse.de
#    --host localhost 490017 INSTALLONLY=1
#    http://assam.suse.cz/tests/2313#step/hostname_inst/5
#
#    Test2
#    Start installation with ifcfg=..., means set up a static network (without
#    dhcp).
#    Check whether hostname 'install' is set.
#    /usr/share/openqa/script/clone_job.pl --from http://openqa.suse.de
#    --host localhost 490017 EXTRABOOTPARAMS="ifcfg=10.0.2.99/24"
#    INSTALLONLY=1
#    http://assam.suse.cz/tests/2317#step/hostname_inst/5
#
#    Test3
#    Start qemu with `-netdev user,hostname=myhostname`. Start installation
#    ifcfg=*=dhcp.
#    Check whether hostname is set to 'myhostname'.
#    /usr/share/openqa/script/clone_job.pl --from http://openqa.suse.de
#    --host localhost 490017 EXTRABOOTPARAMS="ifcfg=*=dhcp"
#    EXPECTED_INSTALL_HOSTNAME=myhostname
#    NICTYPE_USER_OPTIONS="hostname=myhostname" INSTALLONLY=1
#    http://assam.suse.cz/tests/2316#step/hostname_inst/5
#
#    Test4
#    Start installation with `hostname=myhostname` on kernel cmd line. Check
#    whether hostname is set to 'myhostname'.
#    /usr/share/openqa/script/clone_job.pl --from http://openqa.suse.de
#    --host localhost 490017 EXTRABOOTPARAMS="hostname=myhostname"
#    EXPECTED_INSTALL_HOSTNAME=myhostname INSTALLONLY=1
#    http://assam.suse.cz/tests/2312#step/hostname_inst/5
# G-Maintainer: Michal Nowak <mnowak@suse.com>

use base "y2logsstep";
use strict;
use warnings;
use testapi;

sub run() {
    my $self = shift;

    assert_screen "before-package-selection";

    select_console('install-shell');

    if (my $expected_install_hostname = get_var('EXPECTED_INSTALL_HOSTNAME')) {
        # EXPECTED_INSTALL_HOSTNAME contains expected hostname YaST installer
        # got from environment (DHCP, 'hostname=' as a kernel cmd line argument
        assert_script_run "test \"\$(hostname)\" == \"$expected_install_hostname\"";
    }
    else {
        # 'install' is the default hostname if no hostname is get from environment
        assert_script_run 'test "$(hostname)" == "install"';
    }
    save_screenshot;

    select_console('installation');

    assert_screen "inst-returned-to-yast";
}

1;
# vim: set sw=4 et:
