# SSH SERIAL CONTENT PIPE MODULE
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This module pipes ssh serial content from virtual machine to worker
# process over SUT machine on which the virtual machine runs.
#
# Maintainer: Wayne Chen <wchen@suse.com>, qe-virt@suse.de
package ssh_serial_pipe_base;

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use Carp;
use Net::SSH2 'LIBSSH2_ERROR_EAGAIN';
use Proc::Daemon;
use Cwd qw(getcwd);
use File::Spec::Functions qw(catfile);
use Mojo::File 'path';
use Time::Seconds;

use constant SSH_SERIAL_READ_BUFFER_SIZE => 4096;
use constant SSH_COMMAND_TIMEOUT_MS => 300000;

sub activate_ssh_multiplexion {
    my ($self, %args) = @_;
    $args{host} //= '';
    $args{pwd} //= $testapi::password;
    $args{user} //= 'root';
    $args{port} //= 22;
    die('Need hostname to ssh to') if (!$args{host});

    my $sshcon = $self->activate_ssh_connection(
        hostname => $args{host},
        password => $args{pwd},
        username => $args{user},
        port => $args{port}
    );
    my $sshchan = $self->activate_ssh_channel(sshcon => $sshcon);
    return $sshcon, $sshchan;
}

sub activate_ssh_connection {
    my ($self, %args) = @_;
    $args{host} //= '';
    $args{user} //= 'root';
    $args{pwd} //= $testapi::password;
    $args{key} //= '';
    $args{port} ||= 22;
    die('Need hostname to ssh to') if (!$args{host});

    # timeout requires libssh2 >= 1.2.9 so not all versions might have it
    my $sshcon = Net::SSH2->new(timeout => ($bmwqemu::vars{SSH_COMMAND_TIMEOUT_S} // 5 * ONE_MINUTE) * 1000);

    # Retry multiple times in case the guest is not running yet
    my $counter = $bmwqemu::vars{SSH_CONNECT_RETRY} // 5;
    my $interval = $bmwqemu::vars{SSH_CONNECT_RETRY_INTERVAL} // 10;
    my $con_pretty = "$args{user}\@$args{host}";
    $con_pretty .= ":$args{port}" unless $args{port} == 22;
    while ($counter > 0) {
        if (!$sshcon->connect($args{host}, $args{port})) {
            my @e = $sshcon->error;
            diag("Could not connect to $con_pretty: $e[2]. Retrying up to $counter more times after sleeping ${interval}s");
            sleep($interval);
            $counter--;
            next;
        }
        if ($args{key}) {
            $sshcon->auth_publickey(username => $args{user}, publickey_path => "$args{key}.pub", privatekey_path => $args{key});
        }
        elsif ($args{pwd}) {
            $sshcon->auth(username => $args{user}, password => $args{pwd});
        }
        if ($sshcon->auth_ok) {
            diag "SSH connection to $con_pretty established";
        }
        else {
            $sshcon->die_with_error("SSH connection to $con_pretty can not be established");
        }
        last;
    }
    return $sshcon;
}

sub activate_ssh_channel {
    my ($self, %args) = @_;
    $args{sshcon} //= '';
    die('Need ssh connection to channel to') if (!$args{sshcon});

    my $sshchan = $args{sshcon}->channel() or $args{sshcon}->die_with_error('Cannot open SSH channel');
    $sshchan->blocking(0);
    $sshchan->pty(1);
    $sshchan->ext_data('merge');
    return $sshchan;
}

sub pipe_ssh_serial {
    my ($self, %args) = @_;
    $args{sshcon} //= '';
    $args{sshchan} //= '';
    $args{srcserial} //= '/dev/sshserial';
    $args{dstserial} //= '/dev/sshserial';
    $args{serialfile} //= 'serial0.txt';
    $args{seriallog} //= '/tmp/seriallog.txt';

    path($args{seriallog})->open('>>')->print(localtime() . "  Need ssh connection and channel to pipe ssh serial content")
      if (!$args{sshcon} or !$args{sshchan});

    $args{sshcon}->blocking(1);
    path($args{seriallog})->open('>>')->print(localtime() . " Can not run source serial dev: $args{srcserial}")
      if (!$args{sshchan}->exec("rm -f $args{srcserial}; mkfifo $args{srcserial}; chmod 666 $args{srcserial}; while true; do cat $args{srcserial}; done"));
    $args{sshcon}->blocking(0);

    my $work_dir = getcwd();
    my $pid_file = catfile($work_dir, 'daemon_pipe_ssh_serial.pid');
    my $daemon = Proc::Daemon->new(
        work_dir => $work_dir,
        pid_file => $pid_file,
        child_STDOUT => $args{seriallog},
        child_STDERR => $args{seriallog}
    );

    # Call the Init() method
    my $child_pid = $daemon->Init;
    if ($child_pid) {
        # Parent process: The program exits here.
        path($args{seriallog})->open('>>')->print(localtime() . " Parent exiting, child process started with PID: $child_pid\n");
        upload_logs("$args{seriallog}");
        exit;
    }
    else {
        # Child process: The program's daemon logic runs here.
        path($args{seriallog})->open('>>')->print(localtime() . " Child process running as a daemon with PID: $$\n");
        my $buffer;
        while (1) {
            while (defined(my $bytes_read = $args{sshchan}->read($buffer, SSH_SERIAL_READ_BUFFER_SIZE))) {
                return 1 unless $bytes_read > 0;
                path($args{seriallog})->open('>>')->print(localtime() . " $buffer");
                path($args{serialfile})->open('>>')->print($buffer);
            }
            my ($error_code, $error_name, $error_string) = $args{sshcon}->error;
            if ($error_code == LIBSSH2_ERROR_EAGAIN) {
                $self->deactivate_ssh_channel(sshchan => $args{sshcon});
                $self->deactivate_ssh_connection(sshcon => $args{sshcon});
                last;
            }
        }
        upload_logs("$args{seriallog}");
    }
    return 1;
}

sub deactivate_ssh_connection {
    my ($self, %args) = @_;
    $args{sshcon} //= '';

      return unless $args{sshcon};
    diag("Closing SSH connection with " . $args{ssh}->hostname);
    $args{ssh}->disconnect;
    return;
}

sub deactivate_ssh_channel {
    my ($self, %args) = @_;
    $args{sshchan} //= '';

    return unless $args{sshchan};
    $args{sshchan}->close;
    return;

}

1;
