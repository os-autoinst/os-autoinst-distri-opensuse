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

# test for equivalent of bug https://bugzilla.novell.com/show_bug.cgi?id=
sub run() {
    my $self = shift;
    script_run('test -L /etc/mtab && echo OK || echo fail');
    assert_screen "test-mtab-1", 3;
    script_run('cat /etc/mtab');
    save_screenshot;
}

1;
# vim: set sw=4 et:
