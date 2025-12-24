# SSH SERIAL CONTENT PIPE MODULE
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This module pipes ssh serial content from virtual machine to worker
# process over SUT machine on which the virtual machine runs.
#
# Variables:
# SERIAL_SOURCE_ADDRESS
# SERIAL_SOURCE_DEVICE
# INTERIM_GUEST_UPGRADE_LIST
#
# Maintainer: Wayne Chen <wchen@suse.com>, qe-virt@suse.de
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Maintainer: Wayne Chen <wchen@suse.com>, qe-virt@suse.de
package ssh_serial_pipe;

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use Carp;
use utils;
use Utils::Backends;
use Proc::Background;
use LWP::Simple;
use LWP::UserAgent;
use POSIX qw(strftime);

our $jump_host;
our $jump_port;
our @ssh_serial_srcaddr = ();
our @ssh_serial_srcdev = ();
our @ssh_serial_pipe = ();

sub run {
    my $self = shift;

    $self->init_ssh_serial_pipe;
    $self->run_ssh_serial_pipe;
    return $self;
}

sub init_ssh_serial_pipe {
    my $self = shift;

    if (is_qemu) {
        my $default_route = script_output("ip route show default | grep -i dhcp | grep -vE br[[:digit:]]+", proceed_on_failure => 1);
        my $default_device = ((!$default_route) ? 'br0' : (split(' ', script_output("ip route show default | grep -i dhcp | grep -vE br[[:digit:]]+ | head -1")))[4]);
        set_var('SUT_IP', (split('/', (split(' ', script_output("ip addr show dev $default_device | grep \"inet \"")))[1]))[0]);
    }
    set_var('SERIAL_SOURCE_ADDRESS', get_required_var('UNIFIED_NORMAL_GUEST_IPADDRS')) if (get_var('VIRT_PRJ4_GUEST_UPGRADE'));
    bmwqemu::save_vars();

    if (is_qemu and check_var('NICTYPE', 'user')) {
        $jump_host = '127.0.0.1';
        if (get_var('SSH_HOSTFWD_PORT')) {
            $jump_port = get_required_var('SSH_HOSTFWD_PORT');
        }
        else {
            $jump_port = (split(':', get_required_var('NICTYPE_USER_OPTIONS')))[2];
            $jump_port = chop($jump_port);
        }
    }
    else {
        $jump_host = get_required_var('SUT_IP');
        $jump_port = 22;
    }
    @ssh_serial_srcaddr = split(/\|/, get_required_var('SERIAL_SOURCE_ADDRESS'));
    @ssh_serial_srcdev = get_var('SERIAL_SOURCE_DEVICE') ? split(/\|/, get_var('SERIAL_SOURCE_DEVICE')) : ('') x scalar @ssh_serial_srcaddr;
    while (my ($index, $srcaddr) = each(@ssh_serial_srcaddr)) {
        $ssh_serial_pipe[$index] = {title => '', srcaddr => '', srcdev => 'sshserial'};
        $ssh_serial_pipe[$index]->{title} = 'worker' . get_required_var('WORKER_INSTANCE') . '_ssh_serial_pipe_for_srcaddr' . $srcaddr .
          '_jumphost' . $jump_host . '_jumpport' . $jump_port . '_timestamp' . strftime('%Y%m%d_%H%M%S', localtime());
        $ssh_serial_pipe[$index]->{srcaddr} = $srcaddr;
        $ssh_serial_pipe[$index]->{srcdev} = $ssh_serial_srcdev[$index] if ($ssh_serial_srcdev[$index]);
    }
    return $self;
}

sub run_ssh_serial_pipe {
    my $self = shift;

    my $run_pipe_as_deamon_url = data_url('virt_autotest/ssh_serial_pipe.pl');
    my $run_pipe_as_deamon_file = '/tmp/ssh_serial_pipe.pl';
    my $useragent = LWP::UserAgent->new;
    $useragent->get($run_pipe_as_deamon_url) ? getstore($run_pipe_as_deamon_url, $run_pipe_as_deamon_file) : die("Can not download $run_pipe_as_deamon_file from $run_pipe_as_deamon_url");
    chmod 0777, $run_pipe_as_deamon_file or die "Can not change permission to $run_pipe_as_deamon_file";

    my @guest_upgrade_list = split(/\|/, get_required_var('GUEST_UPGRADE_LIST')) if (get_var('VIRT_PRJ4_GUEST_UPGRADE'));
    my $log_root = get_var('LOG_ROOT', '');
    my $worker_instance = get_required_var('WORKER_INSTANCE');
    my $ret = 0;
    while (my ($index, $pipe) = each(@ssh_serial_pipe)) {
        my @run_pipe_as_deamon_processes = qx(pgrep -f 'worker' . $worker_instance . '_ssh_serial_pipe_for_srcaddr');
        kill('KILL', $_) foreach (@run_pipe_as_deamon_processes);
        my $run_pipe_as_daemon_command = "((nohup /tmp/ssh_serial_pipe.pl --pipe title=$pipe->{title} --pipe srcaddr=$pipe->{srcaddr} --pipe srcdev=$pipe->{srcdev} --logroot $log_root " .
          "--workinst $worker_instance --jumphost $jump_host --jumpport $jump_port --jumppwd $testapi::password --srcaddr $pipe->{srcaddr}) &)";
        record_info("Run $pipe->{title} as daemon", $run_pipe_as_daemon_command);
        Proc::Background->new($run_pipe_as_daemon_command);
        sleep 120;
        @run_pipe_as_deamon_processes = qx(pgrep -f $pipe->{title});
        if (scalar @run_pipe_as_deamon_processes > 0) {
            my $ssh_serial_pipe_processes = qx(pgrep -f $pipe->{title} | xargs ps -f -p);
            $ssh_serial_pipe_processes =~ s/^\s+|\s+$//g;
            record_info("SSH serial pipe $pipe->{title} running in background", $ssh_serial_pipe_processes);
        }
        else {
            my $current_processes = qx(ps aux);
            $current_processes =~ s/^\s+|\s+$//g;
            record_info("SSH serial pipe $pipe->{title} initialization failed", $current_processes, result => 'fail');
            $guest_upgrade_list[$index] = 'abnormal_' . $guest_upgrade_list[$index] if (get_var('VIRT_PRJ4_GUEST_UPGRADE'));
            $ret += 1;
        }
    }

    if (get_var('VIRT_PRJ4_GUEST_UPGRADE')) {
        set_var('INTERIM_GUEST_UPGRADE_LIST', join('|', @guest_upgrade_list));
        bmwqemu::save_vars();
        record_info('Guest upgrade info', "ORIGINAL GUEST_UPGRADE_LIST:" . get_required_var('GUEST_UPGRADE_LIST') . "\nINTERIM_GUEST_UPGRADE_LIST:" . get_required_var('INTERIM_GUEST_UPGRADE_LIST') .
              "\nSERIAL_SOURCE_ADDRESS:" . get_required_var('SERIAL_SOURCE_ADDRESS') . "\nSERIAL_SOURCE_DEVICE:" . get_var('SERIAL_SOURCE_DEVICE', ''));
    }

    if ($ret == 0) {
        record_info("All pipes have been initiated. Main program can now finish.");
    }
    elsif ($ret < scalar @ssh_serial_srcaddr) {
        record_info('Certain pipes have not been initiated successfully', 'Please check back later', result => 'fail');
        my $logfolder = '/var/lib/openqa/pool/' . get_required_var('WORKER_INSTANCE');
        my $logfile = 'ssh_serial_pipe';
        logs_from_worker(folders => "$logfolder/$logfile", logfolder => $logfolder, logfile => 'ssh_serial_pipe', testname => __PACKAGE__);
    }
    else {
        die("All pipes initialization failed");
    }
    return $self;
}

sub test_flags {
    return {
        fatal => 1,
        no_rollback => 1
    };
}

sub post_fail_hook {
    my $self = shift;

    my $logfolder = '/var/lib/openqa/pool/' . get_required_var('WORKER_INSTANCE');
    my $logfile = 'ssh_serial_pipe';
    logs_from_worker(folders => "$logfolder/$logfile", logfolder => $logfolder, logfile => 'ssh_serial_pipe', testname => __PACKAGE__);
    return $self;
}

1;
