# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: Simple 'zypper in' test
# - List download repositories ("zypper lr -d") and redirect to serial output
# - If no specific package is defined, try to install "x3270" in sle or
#   "xdelta3" in openSUSE and "screen"
# - Remove package using rpm -e
# - Check if package was removed
# Maintainer: Richard Brown <rbrownccb@opensuse.org>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

# rpm -q --scripts hello0.rpm
# preinstall scriptlet (using /bin/sh):
# if [ -e /preinstall_fail ] ; then
# 		echo "This rpm pre-install script will now exit 1 to test zypp(er) behaviour"
# 		exit 1
# fi
# if [ -e /preinstall_wait ] ; then
# 	echo "This rpm pre-install script will now touch /preinstall_sleeping and wait for 100s to test zypp(er) behaviour"
# 	touch /preinstall_sleeping
# 	sleep 100
# 	rm -f /preinstall_sleeping
# fi

sub run {
    select_console 'root-console';

    script_run("zypper lr -d | tee /dev/$serialdev");
    my $pkgname = get_var('PACKAGETOINSTALL');
    if (!$pkgname) {
        $pkgname = 'x3270' if check_var('DISTRI', 'sle');
        $pkgname = 'xdelta3' if check_var('DISTRI', 'opensuse');
    }
    zypper_call "in screen $pkgname";
    clear_console;    # clear screen to see that second update does not do any more
    assert_script_run("rpm -e $pkgname");
    assert_script_run("! rpm -q $pkgname");

    script_run 'touch /preinstall_fail';
    script_run 'zypper -n in --allow-unsigned-rpm ' . data_url('zypper/hello0.rpm');
    script_run 'rm -f /preinstall_fail';

    assert_script_run 'export ZYPP_SINGLE_RPMTRANS=1';

    script_run 'touch /preinstall_fail';
    script_run 'zypper -n in --allow-unsigned-rpm ' . data_url('zypper/hello0.rpm');
    script_run 'rm -f /preinstall_fail';

    my $pkgs_to_install = "apache2";
    for ((1 .. 9)) {
        $pkgs_to_install .= ' ' . data_url("zypper/hello$_.rpm");
    }

    assert_script_run "zypper -n in --allow-unsigned-rpm $pkgs_to_install";

    assert_script_run 'unset ZYPP_SINGLE_RPMTRANS';
}

1;
