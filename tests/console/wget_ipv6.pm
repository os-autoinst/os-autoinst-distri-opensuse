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

# test for equivalent of bug https://bugzilla.novell.com/show_bug.cgi?id=598574
sub run() {
    my $self = shift;
    script_run('rpm -q wget');
    script_run('wget -O- -q www3.zq1.de/test.txt');
    assert_screen 'test-wget_ipv6-1', 3;
}

1;
# vim: set sw=4 et:
