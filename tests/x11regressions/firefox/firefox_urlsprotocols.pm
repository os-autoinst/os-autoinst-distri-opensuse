# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Firefox: URLs with various protocols (Case#1436118)
# Maintainer: wnereiz <wnereiz@github>

use strict;
use base "x11regressiontest";
use testapi;
use utils;

sub run {
    my ($self) = @_;
    $self->start_firefox;

    # sites_url
    my %sites_url = (
        http  => "http://jekyllrb.com/",
        https => "https://www.google.com/",
        ftp   => "ftp://mirror.bej.suse.com/",
        local => "file:///usr/share/w3m/w3mhelp.html"
    );

    if (sle_version_at_least('12-SP2')) {
        record_soft_failure 'bsc#1004573';
    }
    else {
        $sites_url{smb} = "smb://mirror.bej.suse.com/dist/";
    }
    for my $proto (sort keys %sites_url) {
        send_key "esc";
        sleep 1;
        send_key "alt-d";
        sleep 1;
        type_string $sites_url{$proto} . "\n";
        $self->firefox_check_popups;
        assert_screen('firefox-urls_protocols-' . $proto, 60);
    }

    $self->exit_firefox;
    if ($sites_url{smb}) {
        # Umount smb directory from desktop
        assert_and_click('firefox-urls_protocols-umnt_smb');
        sleep 1;
        send_key "shift-f10";
        sleep 1;
        send_key "u";
    }

}
1;
# vim: set sw=4 et:
