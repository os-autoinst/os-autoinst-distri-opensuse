# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use testapi;
use strict;

# test for bug https://bugzilla.novell.com/show_bug.cgi?id=598574
sub run() {
    my $self = shift;
    script_run('curl www3.zq1.de/test.txt');
    sleep 2;
    assert_screen 'test-curl_ipv6-1', 3;
    script_run('rpm -q curl libcurl4');
    sleep 2;
    assert_screen 'test-curl_ipv6-2', 3;
}

1;
# vim: set sw=4 et:
