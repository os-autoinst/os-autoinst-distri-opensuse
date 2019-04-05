# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Rails test - just installing and starting server
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use version_utils "is_jeos";
use utils;

sub run {
    select_console 'root-console';
    zypper_call("in gcc make git zlib-devel ruby-devel sqlite3-devel nodejs") if is_jeos;
    # something like `test -f tmp/pids/server.pid; pumactl -P tmp/pids/server.pid stop; !test -f tmp/pids/server.pid`
    # is the correct test procedure on rails >= 5, for earlier versions we
    # need to handle this on our own
    my $cmd = <<'EOF';
zypper -n in -C "rubygem(rails)"
rails new mycoolapp --skip-bundle --skip-test
cd mycoolapp
bundle install
(rails server -b 0.0.0.0 &)
for i in {1..100} ; do sleep 0.1; curl -s http://localhost:3000 | grep "<title>Ruby on Rails" && break ; done
pkill -f "rails server" || pumactl -P tmp/pids/server.pid stop
EOF
    assert_script_run($_, timeout => 120) foreach (split /\n/, $cmd);
}

1;
