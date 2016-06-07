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
    select_console 'user-console';
    validate_script_output('curl -v https://eu.httpbin.org/get 2>&1', sub { m,subjectAltName:[\w\s]+["]?eu.httpbin.org["]? matched, }, 60);
}

1;
# vim: set sw=4 et:
