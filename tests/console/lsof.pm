# Copyright (C) 2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: Test lsof command
# Maintainer: Antonio Caristia <acaristia@suse.com>

use base 'consoletest';
use strict;
use testapi;
use utils 'zypper_call';

sub run {
    my ($self) = @_;
    select_console('root-console');
    zypper_call('in netcat');
    assert_script_run("lsof");
    assert_script_run("lsof -u root");
    assert_script_run("lsof -i");
    assert_script_run("lsof -i :22");
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
    
    type_string("netcat -l 5555 &");
    validate_script_output("lsof -i :5555 |grep netcat", sub { m/TCP/ });
    assert_script_run("killall netcat");
    assert_script_run('lsof -i :5555|grep netcat || test $? -eq 1');

    type_string("netcat -ul 5555 &");
    validate_script_output("lsof -i UDP:5555 |grep netcat", sub { m/UDP/ });
    assert_script_run("killall netcat");
    assert_script_run('lsof -i UDP:5555|grep netcat || test $? -eq 1');

}

1;

