# SUSE's openQA tests
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package:  rabbitmq-server python3-pika
# Summary: rabbitmq test suite based on
#  https://www.rabbitmq.com/tutorials/tutorial-one-python.html
#  Solely added because someone added "rabbitmq" to the Leap42.2 test plan :-)
#
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle);

sub run {
    select_console 'root-console';
    zypper_call 'in rabbitmq-server';
    systemctl 'start rabbitmq-server';
    systemctl 'status rabbitmq-server';
    zypper_call 'in python3-pika wget';
    my $cmd = <<'EOF';
mkdir rabbitmq
cd rabbitmq
wget https://raw.githubusercontent.com/rabbitmq/rabbitmq-tutorials/master/python/send.py
python3 send.py
wget https://raw.githubusercontent.com/rabbitmq/rabbitmq-tutorials/master/python/receive.py
EOF
    assert_script_run($_) foreach (split /\n/, $cmd);
    enter_cmd("timeout 1 python3 receive.py > /dev/$serialdev");
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
    # poo#166541, test rabbitmq-server 3.11+ and erlang 25+ on sle15sp6/sp7
    if (is_sle('>=15-SP6') && is_sle('<16.0')) {
        record_info 'Test rabbitmq-server 3.11+';
        # clean up
        script_run('systemctl stop epmd.socket');
        systemctl 'stop epmd';
        zypper_call 'rm rabbitmq-server erlang';
        script_run('rm -rf /var/lib/rabbitmq');
        script_run('rm -rf /usr/lib{.64}/rabbitmq');

        zypper_call 'in rabbitmq-server31*';
        systemctl 'start rabbitmq-server';
        systemctl 'status rabbitmq-server';
        enter_cmd 'python3 send.py';
        enter_cmd("timeout 1 python3 receive.py > /dev/$serialdev");
        wait_serial(".*Received.*Hello World.*");
        systemctl 'stop rabbitmq-server';
    }
}

1;
