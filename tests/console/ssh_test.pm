# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: sshd
# Summary: Verify the ssh login with password and ssh key
#
# Maintainer: QE Core <qe-core@suse.com>

use warnings;
use base "consoletest";
use strict;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(systemctl exec_and_insert_password permit_root_ssh);

# The test disables the firewall, if true reenable afterwards.
my $reenable_firewall = 0;

sub run {
    my $self = shift;
    select_serial_terminal;

    assert_script_run 'if [ -d ~/.ssh ]; then mv ~/.ssh ~/.ssh_bck; fi';

    # prepare /etc/ssh configuration for openssh with default config in /usr/etc
    script_run 'test -f /usr/etc/ssh/sshd_config -a ! -f /etc/ssh/sshd_config && cp /usr/etc/ssh/sshd_config /etc/ssh/sshd_config';

    # Backup the /etc/ssh/sshd_config
    assert_script_run 'cp /etc/ssh/sshd_config{,_before}';

    if (script_run('systemctl is-active ' . $self->firewall) == 0) {
        $reenable_firewall = 1;
        systemctl('stop ' . $self->firewall);
    }

    # Restart sshd and check it's status
    my $ret = systemctl('restart sshd', ignore_failure => 1);
    systemctl 'status sshd';

    $self->permit_root_ssh();
    my $cmd = "ssh -o StrictHostKeyChecking=no root\@localhost";
    my $hashed_cmd = hashed_string("SR$cmd");

    wait_serial(serial_terminal::serial_term_prompt(), undef, 0, no_regex => 1);
    type_string "$cmd";

    enter_cmd " ; echo $hashed_cmd-\$?-";
    wait_serial(qr/Password:\s*$/i);

    type_password;
    send_key "ret";

    # Generate RSA key for root
    assert_script_run "ssh-keygen -t rsa -P '' -C 'root\@localhost' -f ~/.ssh/id_rsa";
    $cmd = "ssh root\@localhost";

    assert_script_run "su -c \"cp /root/.ssh/{id_rsa.pub,authorized_keys}\"";
    assert_script_run "cat ~/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys";

    assert_script_run "ssh -4v root\@localhost bash -c 'whoami | grep root'";

}

sub ssh_cleanup {
    # Restore ~/.ssh generated
    assert_script_run 'rm -rf ~/.ssh';
    assert_script_run 'if [ -d ~/.ssh_bck ]; then mv ~/.ssh_bck ~/.ssh; fi';

    # Restore the /etc/ssh/sshd_config
    assert_script_run 'cp /etc/ssh/sshd_config{_before,}';

    record_info("Restart sshd", "Restart sshd.service");
    systemctl("restart sshd");
}

sub post_run_hook {
    my $self = shift;
    $self->ssh_cleanup();
    $self->cleanup();
    $self->SUPER::post_run_hook;
}

sub post_fail_hook {
    my $self = shift;
    $self->ssh_cleanup();
    $self->cleanup();
    $self->SUPER::post_fail_hook;
}

sub cleanup() {
    my $self = shift;
    systemctl('start ' . $self->firewall) if $reenable_firewall;
    # Show debug log contents
    script_run('cat /tmp/ssh_log*');
    script_run('rm -f /tmp/ssh_log*');
}

1;
