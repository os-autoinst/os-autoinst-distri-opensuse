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

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use Carp;
use Proc::Daemon;
use File::Path qw(make_path);
use Utils::Backends;

use constant SSH_SERIAL_READ_BUFFER_SIZE => 4096;

sub run {
    my $self = shift;

    if (is_qemu) {
        my $default_route = script_output("ip route show default | grep -i dhcp | grep -vE br[[:digit:]]+", proceed_on_failure => 1);
        my $default_device = ((!$default_route) ? 'br0' : (split(' ', script_output("ip route show default | grep -i dhcp | grep -vE br[[:digit:]]+ | head -1")))[4]);
        set_var('SUT_IP', (split('/', (split(' ', script_output("ip addr show dev $default_device | grep \"inet \"")))[1]))[0]);
    }

    if (get_var('VIRT_PRJ4_GUEST_UPGRADE')) {
        set_var('SERIAL_SOURCE_ADDRESS', get_required_var('UNIFIED_GUEST_IPADDRS'));
        set_var('SERIAL_SOURCE_DEVICE', get_var('UNIFIED_GUEST_SERIALDEV', ''));
    }
    my @ssh_serial_srcaddr = split(/\|/, get_required_var('SERIAL_SOURCE_ADDRESS'));
    my @ssh_serial_srcdev = get_var('SERIAL_SOURCE_DEVICE') ? split(/\|/, get_var('SERIAL_SOURCE_DEVICE')) : ('') x scalar @ssh_serial_srcaddr;
    my @ssh_serial_pipe = ();
    while (my ($index, $srcaddr) = each(@ssh_serial_srcaddr)) {
        $ssh_serial_pipe[$index] = {title => '', source => '', serialdev => 'sshserial'};
        $ssh_serial_pipe[$index]->{title} = 'ssh_serial_pipe_for_' . $srcaddr;
        $ssh_serial_pipe[$index]->{source} = $srcaddr;
        $ssh_serial_pipe[$index]->{serialdev} = $ssh_serial_srcdev[$index] if ($ssh_serial_srcdev[$index]);
    }
    while (my ($index, $pipe) = each(@ssh_serial_pipe)) {
        $self->run_pipe_as_daemon(pipe => $pipe, jump => get_required_var('SUT_IP'), title => $ssh_serial_pipe[$index]->{title},
            index => $index, srcaddr => $ssh_serial_pipe[$index]->{source}, srcdev => $ssh_serial_pipe[$index]->{serialdev});
    }

    diag("All pipes have been daemonized and initiated. Main program can now finish.");
    return $self;
}

sub run_pipe_as_daemon {
    my ($self, %args) = @_;
    $args{pipe} //= '';
    $args{jump} //= get_var('SUT_IP', '');
    $args{index} //= 0;
    $args{title} //= 'ssh_serial_pipe_' . $args{index};
    $args{srcaddr} //= '';
    $args{srcdev} //= 'sshserial';
    $args{serialfile} //= '';
    die('Can not initiate daemon without pipe object, jump host and source address') if (!$args{pipe} or !$args{jump} or !$args{srcaddr});

    eval {
        #my $log_folder = '/tmp/ssh_serial_pipe/';
        my $log_folder = '/var/lib/openqa/pool/' . get_required_var('WORKER_INSTANCE') . '/' . __PACKAGE__ . '/';
        make_path($log_folder, {mode => 0755});
        my $pipe_as_daemon = Proc::Daemon->new(
            work_dir => $log_folder,
            child_STDOUT => $log_folder . __PACKAGE__ . '_output_' . $args{srcaddr},
            child_STDERR => $log_folder . __PACKAGE__ . '_error_' . $args{srcaddr},
            pid_file => $log_folder . __PACKAGE__ . '_pid_' . $args{srcaddr}
        );
        my $pipe_as_daemon_pid = $pipe_as_daemon->Init;

        unless ($pipe_as_daemon_pid) {
            $0 = $args{title} . '_' . $$;

            my $log_file = $log_folder . 'ssh_serial_pipe_' . $args{srcaddr} . '_' . $$ . '.log';
            open(my $log_handle, '>>', $log_file);
            #print $log_handle "$args{title}:$args{source}:$args{serialdev}:$$\n";
            print $log_handle '********** ' . localtime() . ' SSH SERIAL PIPE LOG PID: ' . $$ . ' **********';
            print $log_handle localtime() . ' Pipe process will run as daemon for source: ' . $args{srcaddr} . ' with PID: ' . "$$\n";
            print $log_handle localtime() . ' Pipe process ' . $args{title} . ' PID: ' . $$ . " is now running in the background\n";

            #my ($ssh, $chan) = $self->activate_ssh_multiplexion(host => $args{jump}, pwd => $testapi::password);
            #$self->pipe_ssh_serial(sshcon => $ssh, sshchan => $chan, srcaddr => $args{pipesrc}, pid => $$);
            my $sshcon = Net::SSH2->new(timeout => (300 // 5 * 3600) * 1000);
            my $counter = 5;
            my $con_pretty = "root\@" . $args{jump};
            while ($counter > 0) {
                if ($sshcon->connect($args{jump}, 22)) {
                    $sshcon->auth(username => 'root', password => 'nots3cr3t');
                    if ($sshcon->auth_ok) {
                        print $log_handle localtime() . " SSH connection to $con_pretty established\n";
                        last;
                    }
                }
                else {
                    print $log_handle localtime() . " Could not connect to $con_pretty, Retrying after some seconds...\n";
                    sleep(10);
                    next;
                }
                $counter--;
            }

            my $sshchan = $sshcon->channel() or $sshcon->die_with_error;
            $sshchan->blocking(0);
            $sshchan->pty(1);
            $sshchan->ext_data('merge');

            $sshcon->blocking(1);
       #$sshchan->exec("ssh $args{source} '(for i in `ps axu | grep -i \"cat /dev/$args{serialdev}\" | grep -v grep | awk '{print \$2}'`;do ps -p \$i; done)'");
            if (!$sshchan->exec("ssh $args{source} \"rm -f /dev/$args{serialdev}; mkfifo /dev/$args{serialdev}; chmod 666 /dev/$args{serialdev}; while true; do cat /dev/$args{serialdev}; done\"")) {
                print $log_handle localtime() . " Can not grab serial console\n";
            }
            $sshcon->blocking(0);
            close($log_handle);

            my $buffer;
            my @serial_file = ($log_folder . 'serial0', $log_folder . 'serial0.txt');
            push(@serial_file, $log_folder . $args{serialfile}) if ($args{serialfile});
            while (1) {
                while (defined(my $bytes_read = $sshchan->read($buffer, 4096))) {
                    return 1 unless $bytes_read > 0;
                    foreach my $file (@serial_file) {
                        open(my $file_handle, '>>', $file);
                        print $file_handle $buffer;
                        close($file_handle);
                    }
                }
            }
            exit 0;
        }
    };
    exit 1 if ($@);
}

sub test_flags {
    return {
        no_rollback => 1
    };
}

1;
