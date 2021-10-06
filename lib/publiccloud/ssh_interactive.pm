# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Class with helpers related to SSH Interactive mode
#
# Maintainer: Pavel Dostal <pdostal@suse.cz>

package publiccloud::ssh_interactive;
use base "opensusebasetest";
use testapi;
use Utils::Backends qw(set_sshserial_dev unset_sshserial_dev);
use strict;
use warnings;

our @ISA    = qw(Exporter);
our @EXPORT = qw(ssh_interactive_tunnel ssh_interactive_leave);

sub ssh_interactive_tunnel {
    my ($instance) = @_;

    # Prepare the environment for the SSH tunnel
    my $upload_port = get_required_var('QEMUPORT') + 1;
    my $upload_host = testapi::host_ip();

    $instance->run_ssh_command(
        # Create /dev/sshserial fifo on remote and tail|tee it to /dev/$serialdev on local
        #   timeout => switches to script_run instead of script_output to be used so the test will not wait for the command to end
        #   tunnel the worker port (for downloading from data/ and uploading assets / logs
        cmd      => "'rm -rf /dev/sshserial; mkfifo -m a=rwx /dev/sshserial; tail -fn +1 /dev/sshserial' 2>&1 | tee /dev/$serialdev; clear",
        timeout  => 0,
        no_quote => 1,
        ssh_opts => "-yt -R $upload_port:$upload_host:$upload_port",
        username => 'root'
    );
    sleep 3;
    save_screenshot;

    set_var('SERIALDEV_',               $serialdev);
    set_var('_SSH_TUNNELS_INITIALIZED', 1);

    set_var('AUTOINST_URL_HOSTNAME', 'localhost');
    set_sshserial_dev();
}

sub ssh_interactive_leave {
    # Check if the SSH tunnel is still up and leave the SSH interactive session
    script_run("test -p /dev/sshserial && exit", timeout => 0);

    # Restore the environment to not use the SSH tunnel for upload/download from the worker
    #set_var('SUT_HOSTNAME',          testapi::host_ip());
    set_var('AUTOINST_URL_HOSTNAME', testapi::host_ip());
    unset_sshserial_dev();

    $testapi::distri->set_standard_prompt('root');
}

1;
