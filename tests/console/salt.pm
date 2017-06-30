# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test installation of salt-master as well as salt-minion on same
#  machine. Test simple operation with loopback.
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: fate#318875, fate#320919

use base "consoletest";
use strict;
use testapi;
use utils 'pkcon_quit';

sub run() {
    select_console 'root-console';
    pkcon_quit;
    my $cmd = <<'EOF';
zypper -n in salt-master salt-minion
systemctl start salt-master
systemctl status salt-master
sed -i -e "s/#master: salt/master: localhost/" /etc/salt/minion
systemctl start salt-minion
systemctl status salt-minion
salt-key --accept-all -y
EOF
    assert_script_run($_) foreach (split /\n/, $cmd);
    validate_script_output "salt '*' test.ping | grep -woh True > /dev/$serialdev", sub { m/True/ };
    assert_script_run 'systemctl stop salt-master salt-minion';
}

1;
# vim: set sw=4 et:
