# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Add rails test
#    As coolo wrote, 'nough said. Had it make it work though, his IRC notes
#    had syntax errors ;-)
# G-Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use base "consoletest";
use testapi;

sub run() {
    select_console 'root-console';
    my $cmd = <<'EOF';
zypper -n in -C "rubygem(rails)"
rails new -B mycoolapp
cd mycoolapp
(rails server &)
for i in {1..100} ; do sleep 0.1; curl -s http://localhost:3000 | grep "Welcome" && break ; done
pkill -f "rails server"
EOF
    assert_script_run($_) foreach (split /\n/, $cmd);
}

1;
# vim: set sw=4 et:
