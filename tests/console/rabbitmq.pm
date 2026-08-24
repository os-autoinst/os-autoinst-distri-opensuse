# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rabbitmq-server
# Summary: rabbitmq test suite based on
#  https://www.rabbitmq.com/tutorials/tutorial-one-python.html
#
# Maintainer: QE Core <qe-core@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use utils;
use version_utils qw(is_sle);
use package_utils qw(install_package uninstall_package);
use serial_terminal qw(select_serial_terminal);

sub get_all_rabbitmq_versions() {
    my @rabbitmq_versions = split(/\n/, script_output(qq[zypper se -t package rabbitmq-server | awk -F '|' '\$2 ~ /rabbitmq-server[0-9]* / {print \$2}' | tr -d ' ' | sort -u]));
    record_info("Available versions", "All available rabbitmq versions are: @rabbitmq_versions");
    return @rabbitmq_versions;
}

sub download_go_script() {
    my $curl_opts = "--retry 1 --retry-max-time 60 -D - -O";
    my $cmd = <<EOF;
mkdir rabbitmq
cd rabbitmq
curl $curl_opts https://raw.githubusercontent.com/rabbitmq/rabbitmq-tutorials/master/go/send.go
go mod init amqp-go
go get github.com/rabbitmq/amqp091-go
go mod tidy
curl $curl_opts https://raw.githubusercontent.com/rabbitmq/rabbitmq-tutorials/master/go/receive.go
EOF
    assert_script_run($_) foreach (split /\n/, $cmd);
}

sub run {
    select_serial_terminal;
    install_package('go curl', trup_apply => 1);
    download_go_script();
    my @rabbitmq_versions = get_all_rabbitmq_versions();
    foreach my $rabbitmq_spec_version (@rabbitmq_versions) {
        install_package("$rabbitmq_spec_version", trup_reboot => 1);
        record_info('rabbitmq-server&erlang versions: ', script_output('rpm -qa | grep -E "rabbitmq-server|erlang"'));
        systemctl 'start rabbitmq-server';
        systemctl 'status rabbitmq-server';
        record_info('Send/receive message: "Hello World!"');
        script_run('go run send.go', timeout => 120);
        enter_cmd('timeout 2 go run receive.go');
        wait_serial(".*Received.*Hello World.*") || die 'Failed to receive message';
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
        # clean up
        script_run('systemctl stop epmd.socket');
        systemctl 'stop epmd';
        uninstall_package("$rabbitmq_spec_version erlang*", trup_reboot => 1);
        script_run('rm -rf /var/lib/rabbitmq');
        script_run('rm -rf /usr/lib{.64}/rabbitmq');
    }
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    script_run 'rabbitmq-diagnostics &> /var/log/rabbitmq/rabbitmq-diagnostics.log';
    script_run 'tar -zcvf rabbitmq.tar.gz /var/log/rabbitmq';
    upload_logs 'rabbitmq.tar.gz';
    upload_logs '/var/lib/rabbitmq/erl_crash.dump';
}

1;
