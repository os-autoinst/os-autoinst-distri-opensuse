# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: gnuhealth stack installation
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use strict;
use testapi;

sub run() {
    my ($self) = @_;
    ensure_installed 'gnuhealth';
    x11_start_program 'xterm';
    assert_screen 'xterm';
    become_root;
    assert_script_run 'systemctl start postgresql';
    wait_screen_change { script_run 'su postgres', 0 };
    script_run 'sed -i -e \'s/\(local.*all.*all.*\)md5/\1trust/g\' /var/lib/pgsql/data/pg_hba.conf', 0;
    script_run 'psql -c "CREATE USER tryton WITH CREATEDB;"',                                        0;
    wait_screen_change { send_key 'ctrl-d' };
    assert_script_run 'systemctl restart postgresql';
    # generate the crypted password as described in /etc/tryton/trytond.conf
    script_run
'pw=$(python -c \'import getpass,crypt,random,string; print crypt.crypt(getpass.getpass(), "".join(random.sample(string.ascii_letters + string.digits, 8)))\')',
      0;
    wait_still_screen(1);
    type_string "susetesting\n";
    assert_script_run 'sed -i -e "s/^.*super_pwd.*\$/super_pwd = ${pw}/g" /etc/tryton/trytond.conf';
    assert_script_run 'systemctl start trytond';
    # exit from root session
    send_key 'ctrl-d';
    # exit xterm
    send_key 'ctrl-d';
}

1;
# vim: set sw=4 et:
