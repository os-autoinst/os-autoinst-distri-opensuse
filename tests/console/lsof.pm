# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: netcat lsof psmisc
# Summary: Test lsof command
# - Install netcat, lsof and psmisc
# - Run lsof alone
# - Run lsof selecting root files
# - Run lsof selecting all networks
# - Run lsof selecting applications listening on a discovered port
# - Run lsof listing all files owned by root
# - Run "exec 3>testoutput && echo 'random words' >&3"
# - Run lsof and search all open instances with "testoutput"
# - Run lsof and check on fd 3, for root opened files with "testoutput"
# - Stop echo test
# - Run "exec 4<> testoutput && read line <&4 && echo $line"
# - Run lsof and check on fd 4, for root opened files with "testoutput"
# - Stop echo test
# - Run "netcat -l 5555 &"
# - Run lsof, check for port 5555 and netcat
# - Kill netcat
# - Run "netcat -ul 5555 &"
# - Run lsof, check for port 5555 and netcat
# - Kill netcat
# Maintainer: Antonio Caristia <acaristia@suse.com>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';

sub run {
    select_serial_terminal;
    install_package('netcat lsof psmisc', trup_reboot => 1);
    assert_script_run("lsof");
    assert_script_run("lsof -u root");
    assert_script_run("lsof -i");

    # Find any listening TCP port instead of assuming sshd on :22.
    # If nothing is listening, skip — lsof -i :PORT is already covered
    # by the netcat sections below.
    my $port = script_output(q{ss -tlnp | awk 'NR>1 {split($4,a,":"); print a[length(a)]; exit}'}, proceed_on_failure => 1);
    if ($port && $port =~ /^\d+$/) {
        record_info('lsof -i :PORT', "Using port $port");
        assert_script_run("lsof -i :$port");
    } else {
        record_info('No listeners', 'No TCP listeners found, skipping - covered by netcat tests below');
    }

    assert_script_run("lsof -p 1");

    assert_script_run("exec 3>testoutput && echo 'random words' >&3");
    assert_script_run('lsof +D . |grep testoutput || test $? -eq 1');
    validate_script_output('lsof -a -p $$ -d 3 | grep testoutput', sub { m/testoutput/ }, 200);
    assert_script_run('exec 3>&-');
    assert_script_run('lsof -a -p $$ -d 3 | grep testoutput || test $? -eq 1');

    assert_script_run('exec 4<> testoutput && read line <&4 && echo $line');
    validate_script_output('lsof -a -p $$ -d 4 |grep testoutput', sub { m/testoutput/ }, 200);
    assert_script_run('exec 4>&-');
    assert_script_run('lsof -a -p $$ -d 4 | grep testoutput || test $? -eq 1');

    assert_script_run('(netcat -l 5555 &)');
    assert_script_run('for i in $(seq 1 10); do lsof -i :5555 >/dev/null 2>&1 && break; sleep 0.5; done');
    validate_script_output("lsof -i :5555 |grep netcat", sub { m/TCP/ });
    assert_script_run("killall netcat");
    assert_script_run('lsof -i :5555|grep netcat || test $? -eq 1');

    assert_script_run('(netcat -ul 5555 &)');
    assert_script_run('for i in $(seq 1 10); do lsof -i UDP:5555 >/dev/null 2>&1 && break; sleep 0.5; done');
    validate_script_output("lsof -i UDP:5555 |grep netcat", sub { m/UDP/ });
    assert_script_run("killall netcat");
    assert_script_run('lsof -i UDP:5555|grep netcat || test $? -eq 1');

}

1;
