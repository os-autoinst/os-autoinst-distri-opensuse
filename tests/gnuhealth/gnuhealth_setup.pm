# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Initial setup of gnuhealth, e.g. database
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use strict;
use warnings;
use testapi;
use version_utils qw(is_leap is_tumbleweed);
use utils 'systemctl';

sub run() {
    my ($self) = @_;
    x11_start_program('xterm');
    become_root;
    systemctl 'start postgresql';
    wait_screen_change { script_run 'su postgres', 0 };
    script_run 'sed -i -e \'s/\(\(local\|host\).*all.*all.*\)\(md5\|ident\)/\1trust/g\' /var/lib/pgsql/data/pg_hba.conf', 0;
    script_run 'psql -c "CREATE USER tryton WITH CREATEDB;"',                                                             0;
    if (is_tumbleweed || is_leap('42.3+')) {
        script_run 'createdb gnuhealth --encoding=\'UTF8\' --owner=tryton', 0;
    }
    script_run 'exit', 0;
    systemctl 'restart postgresql';
    # generate the crypted password as described in /etc/tryton/trytond.conf
    # but with no randomness for easier testing and preventing a stray '/' to
    # destroy the sed call
    script_run 'pw=$(python -c \'import getpass,crypt; print(crypt.crypt(getpass.getpass(), str(123456789)))\')', 0;
    wait_still_screen(1);
    type_string "susetesting\n";
    assert_script_run 'sed -i -e "s/^.*super_pwd.*\$/super_pwd = ${pw}/g" /etc/tryton/trytond.conf';
    if (is_tumbleweed || is_leap('42.3+')) {
        assert_script_run 'echo susetesting > /tmp/pw';
        assert_script_run 'sudo -u tryton env TRYTONPASSFILE=/tmp/pw trytond-admin -c /etc/tryton/trytond.conf --all -d gnuhealth --password', 600;
    }
    systemctl 'start trytond';
    # exit from root session
    send_key 'ctrl-d';
    # exit xterm
    send_key 'ctrl-d';
}

sub test_flags() {
    return {fatal => 1};
}

1;
