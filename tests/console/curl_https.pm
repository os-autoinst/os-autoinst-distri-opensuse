# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: ensure curl is able to successfully connect to a https site
#          without certificate errors.
# - switch to normal user
# - connect to a website using https (retry multiple times in case of failure)
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "consoletest";
use testapi;
use strict;
use warnings;

# test for bug https://bugzilla.novell.com/show_bug.cgi?id=598574
sub run {
    select_console 'user-console';

    # arbitrary number of retries
    my $max_retries = 7;
    for (1 .. $max_retries) {
        eval {
            validate_script_output('curl -f -v https://httpbin.org/get 2>&1', sub { m,subjectAltName:[\w\s]+["]?httpbin.org["]? matched, });
        };
        last unless ($@);
        diag "curl -f -v https://eu.httpbin.org/get failed: $@";
        diag "Maybe the network is busy. Retry: $_ of $max_retries";
    }
    die "curl failed (with retries)" if $@;
}

1;
