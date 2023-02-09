# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openssh
# Summary: console test pre setup, performing actions required to run tests
# which are supposed to be reverted e.g. stoping and disabling packagekit and so on
# Permanent changes are now executed in system_prepare module
# - Setup passwordless & questionless ssh login to localhost 127.0.0.1 ::1
# - Disable/stop serial-getty service
# - Disable mail notifications system-wide
# - Enable pipefail system-wide
# - Disable/stop packagekit service
# - Check console font
# - Disable autovt@tty2 service for GNOME tests

# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils 'is_leap';
use utils qw(check_console_font disable_serial_getty);
use Utils::Backends qw(has_ttys);
use Utils::Systemd qw(disable_and_stop_service systemctl);
use Utils::Logging 'export_logs';
use strict;
use warnings;


sub run {
    my $user = $testapi::username;
    select_serial_terminal;

    systemctl('start sshd');

    # generate ssh key and use same key for root and bernhard
    if (script_run('! test -e ~/.ssh/id_rsa') == 0) {
        assert_script_run('ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa');
    }

    # copy and add root key into authorized_keys and public key into known_hosts of both root and user
    # $user is not created or used, like LIVECD or ROOTONLY tests
    if (get_var('ROOTONLY') || get_var('LIVECD') || get_var('HA_CLUSTER')) {
        assert_script_run('mkdir -pv ~/.ssh');
        assert_script_run('touch ~/.ssh/{authorized_keys,known_hosts}');
        assert_script_run('chmod 600 ~/.ssh/*');
        assert_script_run('cat ~/.ssh/id_rsa.pub | tee -a ~/.ssh/authorized_keys');
        assert_script_run("ssh-keyscan localhost 127.0.0.1 ::1 | tee -a ~/.ssh/known_hosts");
    }
    else {
        assert_script_run("mkdir -pv ~/.ssh ~$user/.ssh");
        assert_script_run("cp ~/.ssh/id_rsa ~$user/.ssh/id_rsa");
        assert_script_run("touch ~{,$user}/.ssh/{authorized_keys,known_hosts}");
        assert_script_run("chmod 600 ~{,$user}/.ssh/*");
        assert_script_run("chown -R bernhard ~$user/.ssh");
        assert_script_run("cat ~/.ssh/id_rsa.pub | tee -a ~{,$user}/.ssh/authorized_keys");
        assert_script_run("ssh-keyscan localhost 127.0.0.1 ::1 | tee -a ~{,$user}/.ssh/known_hosts");
    }

    # Stop serial-getty on serial console to avoid serial output pollution with login prompt
    disable_serial_getty;

    # Prevent mail notification messages to show up in shell and interfere with running console tests
    script_run 'echo "unset MAILCHECK" >> /etc/bash.bashrc.local';
    script_run 'echo "set -o pipefail" >> /etc/bash.bashrc.local';
    script_run '. /etc/bash.bashrc.local';
    disable_and_stop_service('packagekit.service', mask_service => 1);

    # switch to root console and print the current console font to stdout
    # make a use of selected root-console in check_console_font to apply
    # the same environment changes as to root-virtio
    if (has_ttys()) {
        check_console_font;
        script_run '. /etc/bash.bashrc.local';
    }

    # workaround for boo#1205518, stops getty for tty2 so that it won't compete with gdm
    if (is_leap(">=15.4") && check_var('DESKTOP', 'gnome')) {
        assert_script_run('systemctl mask autovt@tty2');
    }
}

sub post_fail_hook {
    my $self = shift;
    select_console 'log-console', timeout => 180;
    export_logs();
    $self->export_logs_locale();
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
