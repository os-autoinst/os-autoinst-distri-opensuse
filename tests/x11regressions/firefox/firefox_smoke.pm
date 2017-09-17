# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case#1479153 Firefox: Smoke Test
# Maintainer: wnereiz <wnereiz@github>

use strict;
use base "x11regressiontest";
use testapi;

sub run {
    my ($self) = @_;

    $self->start_firefox;
    assert_screen('firefox-gnome', 90);

    # Topsites
    my @topsite = ('www.gnu.org', 'www.opensuse.org');
    for my $site (@topsite) {
        send_key "esc";
        send_key "alt-d";
        sleep 1;
        type_string $site. "\n";
        $self->firefox_check_popups;
        assert_screen('firefox-topsite_' . $site, 120);
    }

    # Help
    send_key "alt-h";
    sleep 1;
    send_key "a";
    assert_screen('firefox-help', 30);
    send_key "esc";

    # Exit
    $self->exit_firefox;

}

sub test_flags {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
