# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use strict;
use testapi;
use utils;

my @sites = qw(en.opensuse.org www.slashdot.com www.freshmeat.net www.microsoft.com www.yahoo.com www.ibm.com www.hp.com www.intel.com www.amd.com www.asus.com www.gigabyte.com fractal.webhop.net openqa.opensuse.org http://openqa.opensuse.org/images/openqaqr.png http://openqa.opensuse.org/opensuse/permanent/video/openSUSE-DVD-x86_64-Build0039-nice3.ogv http://openqa.opensuse.org/opensuse/qatests/ER3_020_cut.webm software.opensuse.org about:memory);

sub open_tab {
    my $addr = shift;
    send_key "ctrl-t";    # new tab
    sleep 2;
    type_string $addr;
    sleep 2;
    send_key "ret";
    sleep 6;
    send_key "pgdn";
    sleep 1;
}

sub run() {
    my $self = shift;
    x11_start_program("firefox");
    assert_screen_with_soft_timeout('test-firefox_stress-1', soft_timeout => 3);
    foreach my $site (@sites) {
        open_tab($site);
        if ($site =~ m/openqa/) { assert_screen_with_soft_timeout('test-firefox_stress-2', soft_timeout => 3); }
    }
    assert_screen_with_soft_timeout('test-firefox_stress-3', soft_timeout => 3);
    send_key "alt-f4";
    sleep 2;
    send_key "ret";    # confirm "save&quit"
    wait_idle;

    # re-open to see how long it takes to open all tabs together
    x11_start_program("firefox");
    assert_screen_with_soft_timeout('test-firefox_stress-4', soft_timeout => 3);
    send_key "alt-f4";
    sleep 2;
    send_key "ret";    # confirm "save&quit"
}

1;
# vim: set sw=4 et:
