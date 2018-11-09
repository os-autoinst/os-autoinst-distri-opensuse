# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: rabbitmq test suite based on
#  https://www.rabbitmq.com/tutorials/tutorial-one-python.html
#  Solely added because someone added "rabbitmq" to the Leap42.2 test plan :-)
#
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "consoletest";
use strict;
use testapi;
use utils 'systemctl';

sub run {
    select_console 'root-console';
    assert_script_run('zypper -n in rabbitmq-server wget');
    systemctl 'start rabbitmq-server';
    systemctl 'status rabbitmq-server';
    assert_script_run('zypper -n in python-pika');
    my $cmd = <<'EOF';
mkdir rabbitmq
cd rabbitmq
wget https://raw.githubusercontent.com/rabbitmq/rabbitmq-tutorials/master/python/send.py
python send.py
wget https://raw.githubusercontent.com/rabbitmq/rabbitmq-tutorials/master/python/receive.py
EOF
    assert_script_run($_) foreach (split /\n/, $cmd);
    type_string("timeout 1 python receive.py > /dev/$serialdev\n");
    wait_serial(".*Received.*Hello World.*");
    # should be simple assert_script_run but takes too long to stop so
    # workaround
    my $ret = script_run('systemctl stop rabbitmq-server');
    if (!defined($ret)) {
        record_soft_failure 'boo#1029031 stopping systemd service takes more than 90s';
        send_key 'ctrl-c';
        # ignore non-zero exit code when collecting more data on soft fail
        script_run("systemctl status --no-pager rabbitmq-server | tee /dev/$serialdev");
        script_run("rpm -q --changelog rabbitmq-server | head -n 60 | tee /dev/$serialdev");
        systemctl 'stop rabbitmq-server', timeout => 300;
    }
}

1;
