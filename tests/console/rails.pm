# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rubygem(rails)
# Summary: Rails test - just installing and starting server
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use testapi;

sub run {
    select_console 'root-console';
    # something like `test -f tmp/pids/server.pid; pumactl -P tmp/pids/server.pid stop; !test -f tmp/pids/server.pid`
    # is the correct test procedure on rails >= 5, for earlier versions we
    # need to handle this on our own
    my $cmd = <<'EOF';
zypper -n in --recommends -C "rubygem(rails)"
rails new mycoolapp --skip-bundle --skip-test --skip-thruster --skip-brakeman --skip-rubocop
cd mycoolapp
(rails server -b 0.0.0.0 &)
for i in {1..100} ; do sleep 0.1; curl -s http://localhost:3000 | grep "<title>Ruby on Rails" && break ; done
pkill -f "rails server" || pumactl -P tmp/pids/server.pid stop
EOF
    assert_script_run($_) foreach (split /\n/, $cmd);
}

1;
