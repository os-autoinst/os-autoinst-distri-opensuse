# SUSE's openQA tests
#
# Copyright 2017-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Initial setup of gnuhealth, e.g. database
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use testapi;
use version_utils 'is_leap';
use utils 'systemctl';
use x11utils;

sub run() {
    my ($self) = @_;
    x11_start_program(default_gui_terminal);
    become_root;
    systemctl 'start postgresql';
    wait_screen_change { script_run 'su postgres', 0 };
    script_run 'sed -i -e \'s/\(\(local\|host\).*all.*all.*\)\(md5\|ident\)/\1trust/g\' /var/lib/pgsql/data/pg_hba.conf', 0;

    script_run 'psql -c "CREATE USER tryton WITH CREATEDB;"', 0;
    script_run 'createdb gnuhealth --encoding=\'UTF8\' --owner=tryton', 0;
    script_run 'exit', 0;
    systemctl 'restart postgresql';
    assert_script_run 'echo susetesting > /tmp/pw';
    my $cmd = 'sudo -u tryton env TRYTONPASSFILE=/tmp/pw trytond-admin -c /etc/tryton/trytond.conf --all -d gnuhealth --password';
    $cmd .= ' --email root' unless is_leap('<15.2');
    assert_script_run $cmd, 600;
    systemctl 'start gnuhealth';
    # exit from root session
    send_key 'ctrl-d';
    # exit xterm
    send_key 'ctrl-d';
}

sub test_flags() {
    return {fatal => 1};
}

1;
