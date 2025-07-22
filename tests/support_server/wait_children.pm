# Copyright 2015-2018 SUSE Linux GmbH
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Main purpose not allow support server to go down
# until all parallel jobs finish what they are doing
# - Wait for children jobs to finish
# - If REMOTE_CONTROLLER is undefined, send "ctrl-c"
# - Upload logs, if opensuse
# Maintainer: Pavel Sladek <psladek@suse.com>

use base 'basetest';
use testapi;
use lockapi;
use mmapi;

sub run {
    my $self = shift;

    select_console 'root-console';
    # We don't need any logs from support server when running on REMOTE_CONTROLLER for remote SLE installation tests
    enter_cmd("journalctl -f -o short-monotonic |tee /dev/$serialdev") unless (get_var('REMOTE_CONTROLLER'));

    if (check_var("REMOTE_CONTROLLER", "ssh") || check_var("REMOTE_CONTROLLER", "vnc")) {
        mutex_create("installation_done");
    }
    wait_for_children;

    unless (get_var('REMOTE_CONTROLLER')) {
        send_key 'ctrl-c';

        my @server_roles = split(',|;', lc(get_var("SUPPORT_SERVER_ROLES")));
        my %server_roles = map { $_ => 1 } @server_roles;

        # No messages file in openSUSE which use journal by default
        # Write journal log to /var/log/messages for openSUSE
        if (check_var('DISTRI', 'opensuse')) {
            script_run 'journalctl -b -x -o short-precise > /var/log/messages', 90;
        }
        my $log_cmd = "tar cjf /tmp/logs.tar.bz2 /var/log/messages ";
        if (exists $server_roles{qemuproxy} || exists $server_roles{aytest}) {
            $log_cmd .= "/var/log/apache2 ";
        }
        assert_script_run $log_cmd;
        upload_logs "/tmp/logs.tar.bz2";
    }
    $self->result('ok');
}


sub test_flags {
    return {fatal => 1};
}

1;
