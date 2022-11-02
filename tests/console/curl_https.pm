# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: curl_https
# Summary: ensure curl is able to successfully connect to a https site
#          without certificate errors.
#          - switch to normal user
#          - connect to a website using https (retry multiple times in case of failure)
#
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>, QE Security <none@suse.de>
# Tags: poo#106011, poo#109840

use base "consoletest";
use testapi;
use strict;
use warnings;
use utils qw(clear_console ensure_serialdev_permissions);
use Utils::Architectures;
use Utils::Backends;
use serial_terminal 'select_serial_terminal';

# test for bug https://bugzilla.novell.com/show_bug.cgi?id=598574
sub run {

    # On s390x platform, make sure that non-root user has
    # permissions for $serialdev to get openQA work properly.
    # Please refer to bsc#1195620
    select_serial_terminal;    # Switch to root user at first if not
    ensure_serialdev_permissions if (is_s390x);

    # Switch to user console: exclude ipmi backends as under non-root user session the $serialdev can not be found
    select_console 'user-console' if (!is_ipmi);

    # arbitrary number of retries
    my $max_retries = 7;
    for (1 .. $max_retries) {
        eval {
            validate_script_output('curl -f -v https://httpbin.org/get 2>&1', sub { m,subjectAltName:[\w\s]+["]?httpbin.org["]? matched, }, timeout => 90, proceed_on_failure => 1, quiet => 1);
        };
        last unless ($@);
        diag "curl -f -v https://eu.httpbin.org/get failed: $@";
        diag "Maybe the network is busy. Retry: $_ of $max_retries";
    }
    die "curl failed (with retries)" if $@;
}

sub test_flags {
    return {fatal => 0};
}

1;
