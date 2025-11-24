# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rabbitmq-server
# Summary: rabbitmq test suite based on
#  https://www.rabbitmq.com/tutorials/tutorial-one-python.html
#
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use testapi;
use utils;
use version_utils qw(is_sle);
use serial_terminal qw(select_serial_terminal);

sub run {
    select_serial_terminal;
    zypper_call 'in rabbitmq-server go curl';
    systemctl 'start rabbitmq-server';
    systemctl 'status rabbitmq-server';
    my $curl_opts = "--retry 1 --retry-max-time 60 -D - -O";
    my $cmd = <<EOF;
mkdir rabbitmq
cd rabbitmq
curl $curl_opts https://raw.githubusercontent.com/rabbitmq/rabbitmq-tutorials/master/go/send.go
go mod init amqp-go
go get github.com/rabbitmq/amqp091-go
go mod tidy
go run send.go
curl $curl_opts https://raw.githubusercontent.com/rabbitmq/rabbitmq-tutorials/master/go/receive.go
EOF
    assert_script_run($_) foreach (split /\n/, $cmd);
    enter_cmd('timeout 2 go run receive.go');
    wait_serial(".*Received.*Hello World.*");
    # should be simple assert_script_run but takes too long to stop so
    # workaround
    my $ret = script_run('systemctl stop rabbitmq-server');
    if (!defined($ret)) {
        record_soft_failure 'boo#1029031 stopping systemd service takes more than 90s';
        send_key 'ctrl-c';
        # ignore non-zero exit code when collecting more data on soft fail
        script_run('systemctl status --no-pager rabbitmq-server');
        script_run('rpm -q --changelog rabbitmq-server | head -n 60');
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
        enter_cmd 'go run send.go';
        enter_cmd('timeout 2 go run receive.go');
        wait_serial(".*Received.*Hello World.*");
        systemctl 'stop rabbitmq-server';
    }
}

1;
