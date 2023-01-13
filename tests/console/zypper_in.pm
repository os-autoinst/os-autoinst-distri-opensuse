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
use version_utils qw(is_sle is_leap);
use serial_terminal 'select_serial_terminal';
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
    my $timeout = 300;
    select_serial_terminal;
    script_run("zypper lr -d | tee /dev/$serialdev", timeout => $timeout);
    my $pkgname = get_var('PACKAGETOINSTALL');
    if (!$pkgname) {
        $pkgname = 'x3270' if check_var('DISTRI', 'sle');
        $pkgname = 'xdelta3' if check_var('DISTRI', 'opensuse');
    }
    zypper_call "in screen $pkgname";
    clear_console;    # clear screen to see that second update does not do any more
    assert_script_run("rpm -e $pkgname");
    assert_script_run("! rpm -q $pkgname");

    if (!is_sle('<15-SP4') && !is_leap('<15.4') && !check_var('OFFLINE_SUT', '1')) {
        # older releases than 15 don't have the --allow-unsigned-rpm switch
        # also they have issues with this rpms being hashed by something newer than MD5
        # and also this ZYPP_SINGLE_RPMTRANS feature flag is only available as of 15.4
        assert_script_run 'touch /preinstall_fail';
        my $r = script_run 'zypper -n in --allow-unsigned-rpm ' . data_url('zypper/hello0.rpm'), timeout => $timeout;
        die "Unexpected zypper exit code $r - expected 8" unless (defined($r) && ($r == 8));
        assert_script_run 'rm -f /preinstall_fail';

        assert_script_run 'export ZYPP_SINGLE_RPMTRANS=1';

        assert_script_run 'touch /preinstall_fail';
        $r = script_run 'zypper -n in --allow-unsigned-rpm ' . data_url('zypper/hello0.rpm'), timeout => $timeout;
        die "Unexpected zypper exit code $r - expected 8" unless (defined($r) && ($r == 8));
        assert_script_run 'rm -f /preinstall_fail';

        my $pkgs_to_install = "apache2";
        for ((1 .. 9)) {
            $pkgs_to_install .= ' ' . data_url("zypper/hello$_.rpm");
        }

        zypper_call "-n in --allow-unsigned-rpm $pkgs_to_install";
        zypper_call "-n rm hello{1..9}";

        assert_script_run 'unset ZYPP_SINGLE_RPMTRANS';
    }
}


sub post_fail_hook {
    my $self = shift;

    select_console 'log-console';
    upload_logs "/var/log/zypper.log";
    $self->SUPER::post_fail_hook();
}

1;
