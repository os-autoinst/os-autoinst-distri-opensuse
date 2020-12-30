# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Package: xterm rstudio MozillaFirefox git-core
# Summary: Install the rstudio base package and Firefox
# Maintainer: Dan Čermák <dcermak@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use x11utils 'turn_off_screensaver';

sub run() {
    # disable the screensaver for these tests, as some of the steps take longer
    # than the default screensaver timeout and cause random failures
    turn_off_screensaver();

    # use the devel:languages:R:released repository for testing a new version of
    # RStudio before submitting to Factory
    if (defined get_var("RSTUDIO_USE_DEVEL_LANGUAGES_R_RELEASED")) {
        # currently this only works on Tumbleweed
        die unless get_var("VERSION") eq "Tumbleweed";
        x11_start_program('xterm');
        become_root();
        my $repo_url = "https://download.opensuse.org/repositories/devel:/languages:/R:/released/openSUSE_Factory" . (get_var("ARCH") eq "aarch64" ? "_ARM" : "") . "/devel:languages:R:released.repo";
        zypper_call("addrepo $repo_url");
        zypper_call("--gpg-auto-import-keys ref");

        send_key_until_needlematch('generic-desktop', "alt-f4");
    }

    # increase timeout to 15 mins, shouldn't take as long, but it occasionally does
    ensure_installed('rstudio MozillaFirefox', timeout => 900);

    # setup git for later usage
    x11_start_program('xterm');
    assert_script_run('git config --global user.name "Geeko"');
    assert_script_run('git config --global user.email "geeko-noreply@opensuse.org"');
    wait_still_screen(1);
    send_key("alt-f4");
}

sub test_flags {
    return {milestone => 1};
}

1;
