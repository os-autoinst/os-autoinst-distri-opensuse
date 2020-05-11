# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: console test pre setup, performing actions required to run tests
# which are supposed to be reverted e.g. stoping and disabling packagekit and so on
# Permanent changes are now executed in system_prepare module
# - Setup passwordless & questionless ssh login to localhost 127.0.0.1 ::1
# - Disable/stop serial-getty service
# - Disable mail notifications system-wide
# - Enable pipefail system-wide
# - Disable/stop packagekit service
# - Check console font

# Maintainer: Oliver Kurz <okurz@suse.de>

use base "consoletest";
use testapi;
use utils qw(check_console_font disable_serial_getty);
use Utils::Backends qw(has_ttys);
use Utils::Systemd qw(disable_and_stop_service systemctl);
use strict;
use warnings;


sub run {
    my $self = shift;
    $self->select_serial_terminal;

    systemctl('start sshd');

    # generate ssh key and use same key for root and bernhard
    if (script_run('! test -e ~/.ssh/id_rsa') == 0) {
        assert_script_run('ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa');
    }

    # copy and add root key into authorized_keys and public key into known_hosts of both root and bernhard
    assert_script_run('mkdir -pv ~/.ssh ~bernhard/.ssh');
    assert_script_run('cp ~/.ssh/id_rsa ~bernhard/.ssh/id_rsa');
    assert_script_run('touch ~{,bernhard}/.ssh/{authorized_keys,known_hosts}');
    assert_script_run('chmod 600 ~{,bernhard}/.ssh/*');
    assert_script_run('chown bernhard ~bernhard/.ssh/*');
    assert_script_run('cat ~/.ssh/id_rsa.pub | tee -a ~{,bernhard}/.ssh/authorized_keys');
    assert_script_run("ssh-keyscan localhost 127.0.0.1 ::1 | tee -a ~{,bernhard}/.ssh/known_hosts");

    # Stop serial-getty on serial console to avoid serial output pollution with login prompt
    disable_serial_getty;

    # Prevent mail notification messages to show up in shell and interfere with running console tests
    script_run 'echo "unset MAILCHECK" >> /etc/bash.bashrc.local';
    script_run 'echo "set -o pipefail" >> /etc/bash.bashrc.local';
    script_run '. /etc/bash.bashrc.local';
    disable_and_stop_service('packagekit.service', mask_service => 1);

    # init
    check_console_font if has_ttys();
}

sub post_fail_hook {
    my $self = shift;
    select_console('log-console');
    $self->export_logs();
    $self->export_logs_locale();
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
