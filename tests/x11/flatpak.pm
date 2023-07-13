# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test flatpak
#   * Install flatpak
#   * Run smoke test (flatpak --version)
#   * Search for gimp and vlc (both are available on aarch64 as well)
#   * Install gimp
#   * Run gimp
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

use base 'x11test';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils;
use x11utils;

sub run {
    select_serial_terminal;
    # Install flatpak and run basic tests
    zypper_call('in flatpak');
    assert_script_run('flatpak --version | grep -i Flatpak');
    die "flatpak list is not empty" if script_output("flatpak list") != "";
    assert_script_run('flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo');
    assert_script_run('flatpak search gimp | grep -i "org.gimp.GIMP"');
    assert_script_run('flatpak search vlc | grep -i "org.videolan.VLC"');
    assert_script_run('flatpak install -y org.gimp.GIMP', timeout => 300);
    assert_script_run('flatpak list | grep -i gimp');
    # Run flatpak gimp and check if GUI is appearing
    select_console 'x11';
    ensure_unlocked_desktop;
    x11_start_program('flatpak run org.gimp.GIMP', target_match => 'flatpak-gimp');
    wait_still_screen(10);
    assert_and_click('flatpak-gimp');
    wait_still_screen(10);
}

1;
