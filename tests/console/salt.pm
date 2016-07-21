# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use strict;
use testapi;

sub run() {
    select_console 'root-console';
    my $cmd = <<'EOF';
zypper -n in salt-master salt-minion
systemctl start salt-master
systemctl status salt-master
sed -i -e "s/#master: salt/master: localhost/" /etc/salt/minion
systemctl start salt-minion
yes | salt-key --accept-all
salt '*' test.ping
systemctl stop salt-master salt-minion
EOF
    assert_script_run($_) foreach (split /\n/, $cmd);
}

1;
# vim: set sw=4 et:
