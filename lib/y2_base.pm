# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package y2_base;

use base 'opensusebasetest';
use strict;
use warnings;

use ipmi_backend_utils;
use network_utils;
use y2_logs_helper 'get_available_compression';

use testapi qw(is_serial_terminal :DEFAULT);

use Carp::Always;
use File::Copy 'copy';
use File::Path 'make_path';
use Mojo::JSON 'to_json';

use YuiRestClient;
use YuiRestClient::Logger;
use Utils::Logging 'save_and_upload_log';

=head1 y2_base

C<y2_base> - Base class for YaST related functionality in installation and 
running system.

=cut

sub save_strace_gdb_output {
    my ($self, $is_yast_module) = @_;
    return if (get_var('NOLOGS'));

    # Collect yast2 installer or yast2 module trace if is still running
    if (!script_run(qq{ps -eo pid,comm | grep -i [y]2start | cut -f 2 -d " " > /dev/$serialdev}, 0)) {
        chomp(my $yast_pid = wait_serial(qr/^[\d{4}]/, 10));
        return unless defined($yast_pid);
        my $trace_timeout = 120;
        my $strace_log = '/tmp/yast_trace.log';
        my $strace_ret = script_run("timeout $trace_timeout strace -f -o $strace_log -tt -p $yast_pid", ($trace_timeout + 5));

        upload_logs($strace_log, failok => 1) if script_run "! [[ -e $strace_log ]]";

        # collect installer proc fs files
        my @procfs_files = qw(
          mounts
          mountinfo
          mountstats
          maps
          status
          stack
          cmdline
          environ
          smaps);

        my $opt = defined($is_yast_module) ? 'module' : 'installer';
        foreach (@procfs_files) {
            save_and_upload_log("cat /proc/$yast_pid/$_", "/tmp/yast2-$opt.$_");
        }
        # We enable gdb differently in the installer and in the installed SUT
        my $system_management_locked;
        if ($is_yast_module) {
            $system_management_locked = zypper_call('in gdb', exitcode => [0, 7]) == 7;
        }
        else {
            script_run 'extend gdb';
        }
        unless ($system_management_locked) {
            my $gdb_output = '/tmp/yast_gdb.log';
            my $gdb_ret = script_run("gdb attach $yast_pid --batch -q -ex 'thread apply all bt' -ex q > $gdb_output", ($trace_timeout + 5));
            upload_logs($gdb_output, failok => 1) if script_run '! [[ -e /tmp/yast_gdb.log ]]';
        }
    }
}

sub save_system_logs {
    my ($self) = @_;

    return if (get_var('NOLOGS'));

    if (get_var('FILESYSTEM', 'btrfs') =~ /btrfs/) {
        script_run 'btrfs filesystem df /mnt | tee /tmp/btrfs-filesystem-df-mnt.txt';
        script_run 'btrfs filesystem usage /mnt | tee /tmp/btrfs-filesystem-usage-mnt.txt';
        upload_logs('/tmp/btrfs-filesystem-df-mnt.txt', failok => 1);
        upload_logs('/tmp/btrfs-filesystem-usage-mnt.txt', failok => 1);
    }
    script_run 'df -h';
    script_run 'df > /tmp/df.txt';
    upload_logs('/tmp/df.txt', failok => 1);

    # Log connections
    script_run('ss -tulpn > /tmp/connections.txt');
    upload_logs('/tmp/connections.txt', failok => 1);
    # Check network traffic
    script_run('for run in {1..10}; do echo "RUN: $run"; nstat; sleep 3; done | tee /tmp/network_traffic.log');
    upload_logs('/tmp/network_traffic.log', failok => 1);
    # Check VM load
    script_run('for run in {1..3}; do echo "RUN: $run"; vmstat; sleep 5; done | tee /tmp/cpu_mem_usage.log');
    upload_logs('/tmp/cpu_mem_usage.log', failok => 1);

    save_and_upload_log('pstree', '/tmp/pstree');
    save_and_upload_log('ps auxf', '/tmp/ps_auxf');
}

sub save_upload_y2logs {
    my ($self, %args) = @_;

    return if (get_var('NOLOGS') || get_var('Y2LOGS_UPLOADED'));
    $args{suffix} //= '';

    # Do not test/recover network if collect from installation system, as it won't work anyway with current approach
    # Do not recover network on non-qemu backend, as not implemented yet
    $args{no_ntwrk_recovery} //= (get_var('BACKEND') !~ /qemu/);

    # Try to recover network if cannot reach gw and upload logs if everything works
    if (can_upload_logs() || (!$args{no_ntwrk_recovery} && recover_network())) {
        script_run 'sed -i \'s/^tar \(.*$\)/tar --warning=no-file-changed -\1 || true/\' /usr/sbin/save_y2logs';
        my $filename = "/tmp/y2logs$args{suffix}.tar" . get_available_compression();
        script_run "save_y2logs $filename", 180;
        upload_logs($filename, failok => 1);
    } else {    # Redirect logs content to serial
        script_run("journalctl -b --no-pager -o short-precise > /dev/$serialdev");
        script_run("dmesg > /dev/$serialdev");
        script_run("cat /var/log/YaST/y2log > /dev/$serialdev");
    }
    save_screenshot();
    # We skip parsing yast2 logs in each installation scenario, but only if
    # test has failed or we want to explicitly identify failures
    $self->investigate_yast2_failure() unless $args{skip_logs_investigation};
}

=head2 upload_widgets_json

 upload_widgets_json();

Save screenshot and upload widgets json file.

=cut

sub upload_widgets_json {
    save_screenshot;
    if (get_var('YUI_REST_API')) {
        my $json_content;
        eval { $json_content = to_json(YuiRestClient::get_app()->check_connection()) };
        if ($json_content) {
            my $json_path = $autotest::current_test->{name} . '-widgets.json';
            save_tmp_file($json_path, $json_content);
            make_path('ulogs');
            copy(hashed_string($json_path), "ulogs/$json_path");
        } else {
            record_info('rest-api down', 'widgets.json not uploaded because libyui-rest-api server is down.');
        }
    }
}

sub post_fail_hook {
    my $self = shift;
    return if get_var('NOLOGS');
    upload_widgets_json();
    $self->SUPER::post_fail_hook;
}

sub pre_run_hook {
    my $self = shift;

    $self->SUPER::pre_run_hook;
    YuiRestClient::Logger->info($autotest::current_test->{name} . " test module started") if YuiRestClient::is_libyui_rest_api;
}

sub post_run_hook {
    my $self = shift;

    $self->SUPER::post_run_hook;
    save_screenshot unless is_serial_terminal;
    YuiRestClient::Logger->info($autotest::current_test->{name} . " test module finished") if YuiRestClient::is_libyui_rest_api;
}
1;
