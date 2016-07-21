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
    select_console 'user-console';
    assert_script_sudo('zypper -n in rabbitmq-server');
    assert_script_sudo('systemctl start rabbitmq-server');
    assert_script_sudo('systemctl status rabbitmq-server');
    assert_script_sudo('zypper -n in python-pika');
    my $cmd = <<'EOF';
mkdir rabbitmq
cd rabbitmq
wget https://raw.githubusercontent.com/rabbitmq/rabbitmq-tutorials/master/python/send.py
python send.py
wget https://raw.githubusercontent.com/rabbitmq/rabbitmq-tutorials/master/python/receive.py
EOF
    assert_script_run($_) foreach (split /\n/, $cmd);
    validate_script_output 'timeout 1 python receive.py', sub { m/[x] Received 'Hello World!'/ };
    assert_script_sudo('systemctl stop rabbitmq-server');
}

1;
# vim: set sw=4 et:
