# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Firefox: URLs with various protocols (Case#1436118)
# - Launch xterm, kill firefox, cleanup previous firefox configuration, launch
# firefox
# - On firefox, access a http url
# - On firefox, access a https url
# - On firefox, access a ftp url
# - On firefox, access a local url
# - Close firefox
# Maintainer: wnereiz <wnereiz@github>

use strict;
use warnings;
use base "x11test";
use testapi;
use utils;

sub run {
    my ($self) = @_;
    $self->start_firefox_with_profile;

    # sites_url
    my %sites_url = (
        http  => "http://httpbin.org/html",
        https => "https://www.google.com/",
        ftp   => "ftp://mirror.bej.suse.com/",
        local => "file:///usr/share/w3m/w3mhelp.html"
    );

    # smb not supported
    record_soft_failure 'bsc#1004573';
    for my $proto (sort keys %sites_url) {
        $self->firefox_open_url($sites_url{$proto});
        assert_screen('firefox-urls_protocols-' . $proto);
    }

    $self->exit_firefox;
}
1;
