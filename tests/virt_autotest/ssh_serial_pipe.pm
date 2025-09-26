# SSH SERIAL CONTENT PIPE MODULE
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This module pipes ssh serial content from virtual machine to worker
# process over SUT machine on which the virtual machine runs.
#
# Maintainer: Wayne Chen <wchen@suse.com>, qe-virt@suse.de
package ssh_serial_pipe;

use base 'ssh_serial_pipe_base';
use strict;
use warnings;
use testapi;
use Carp;
use Proc::Daemon;
use Cwd qw(getcwd);
use File::Path qw(make_path);

use constant SSH_SERIAL_READ_BUFFER_SIZE => 4096;

sub run {
    my $self = shift;

    my $daemon_path = "/tmp/ssh_serial_pip_daemon";
    my $path_permission = 0755;
    eval {
        make_path($daemon_path, {mode => $path_permission});
    };
    if ($@) {
        if ($@ =~ /File exists/) {
            diag("Directory $daemon_path already exists.\n");
        }
        else {
            die("Error creating directory $daemon_path: $@\n");
        }
    }

    # Create a new Proc::Daemon object with configurations
    my $daemon = Proc::Daemon->new(
        work_dir => $daemon_path,
        child_STDOUT => $daemon_path . '/ssh_serial_pip_daemon_output',
        child_STDERR => $daemon_path . '/ssh_serial_pip_daemon_error',
        pid_file => $daemon_path . '/ssh_serial_pip_daemon_pid'
    );

    # Call the Init() method
    my $pid = $daemon->Init;

    if ($pid) {
        # Parent process: The program exits here.
        diag("Parent exiting, ssh serial pipe child process started with pid: $pid");
	#exit;
    }

    my @pipe_source = split(/\|/, get_required_var('UNIFIED_GUEST_IPADDRS'));
    my $pipe_length = scalar @pipe_source;
    for (my $i = 0; $i < $pipe_length; $i++) {
        my $pid = fork();
        if ($pid == 0 and ($pipe_source[$i] ne 'NO_IP_ADDRESS_FOUND_AT_THE_MOMENT')) {
            print "SSH serial pipe child process running as a daemon with pid: $$\n";
            my ($ssh, $chan) = $self->activate_ssh_multiplexion(host => $pipe_source[$i], pwd => get_required_var('_SECRET_GUEST_PASSWORD'));
            $self->pipe_ssh_serial(sshcon => $ssh, sshchan => $chan);
            exit 0;    # Child process exits after completing its task
        } elsif ($pid > 0) {
            # This is the parent daemon process
            print "Daemon (PID $$) spawned child $i with PID $pid.\n";
        } else {
            warn "Could not fork: $! for pipe source $pipe_source[$i]";
        }
    }
}

1;
