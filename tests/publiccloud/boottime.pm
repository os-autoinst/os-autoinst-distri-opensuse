# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Collect/store bootup time from publiccloud instances.
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'publiccloud::basetest';
use Mojo::Util 'trim';
use testapi;
use db_utils;

sub systemd_time_to_sec
{
    my $str = trim(shift);
    if ($str !~ /^(?<check_min>(?<min>\d{1,2})\s*min\s*)?((?<sec>\d{1,2}\.\d{1,3})s|(?<ms>\d+)ms)$/) {
        die("Unable to parse systemd time '$str'");
    }
    my $sec = $+{sec} // $+{ms} / 1000;
    $sec += $+{min} * 60 if (defined($+{check_min}));
    return $sec;
}

sub extract_analyze {
    my $string = shift;
    my $res    = {};
    $string =~ s/Startup finished in\s*//;
    $string =~ s/=(.+)$/+$1 (overall)/;
    for my $time (split(/\s*\+\s*/, $string)) {
        $time = trim($time);
        my ($time, $type) = $time =~ /^(.+)\s*\((\w+)\)$/;
        $res->{$type} = systemd_time_to_sec($time);
    }
    map { die("Fail to detect $_ timing") unless exists($res->{$_}) } qw(kernel initrd userspace overall);
    return $res;
}

sub extract_blame {
    my $string = shift;
    my $ret    = {};
    for my $line (split(/\r?\n/, $string)) {
        $line = trim($line);
        my ($time, $service) = $line =~ /^(.+)\s+(\S+)$/;
        $ret->{$service} = systemd_time_to_sec($time);
    }
    return $ret;
}

sub do_systemd_analyze {
    my ($instance, %args) = @_;
    $args{timeout} = 120;
    my $start_time = time();
    my $output     = "";
    my @ret;

    # Wait for guest register, before calling syastemd-analyze
    $instance->wait_for_guestregister();
    while ($output !~ /Startup finished in/ && time() - $start_time < $args{timeout}) {
        $output = $instance->run_ssh_command(cmd => 'systemd-analyze', quiet => 1, proceed_on_failure => 1);
        sleep 5;
    }

    die("Unable to get system-analyze in $args{timeout} seconds") unless (time() - $start_time < $args{timeout});
    push @ret, extract_analyze($output);

    $output = $instance->run_ssh_command(cmd => 'systemd-analyze blame', quiet => 1);
    push @ret, extract_blame($output);

    return @ret;
}

sub run {
    my ($self) = @_;

    $self->select_serial_terminal;

    # $tags and $startup_timings are the key/values which get stored in influxdb.
    my $tags = {
        instance_type     => get_required_var('PUBLIC_CLOUD_INSTANCE_TYPE'),
        os_flavor         => get_required_var('FLAVOR'),
        os_version        => get_required_var('VERSION'),
        os_build          => get_required_var('BUILD'),
        os_pc_build       => get_required_var('PUBLIC_CLOUD_BUILD'),
        os_pc_kiwi_build  => get_required_var('PUBLIC_CLOUD_BUILD_KIWI'),
        os_kernel_release => undef,
        os_kernel_version => undef,
    };
    my $startup_timings = {};
    my $blame_timings   = {};

    # Is used to specify thresholds per measurement. If one value is exceeded
    # the test is set to fail.
    my $thresholds = {
        # First boot after provisioning
        kernel     => 15,
        userspace  => 90,
        initrd     => 20,
        overall    => 160,
        ssh_access => 60,

        # Values after soft reboot
        kernel_soft     => 15,
        userspace_soft  => 60,
        initrd_soft     => 10,
        overall_soft    => 120,
        ssh_access_soft => 70,

        # Values after hard reboot
        kernel_hard     => 15,
        userspace_hard  => 60,
        initrd_hard     => 10,
        overall_hard    => 120,
        ssh_access_hard => 60,
    };

    my $provider = $self->provider_factory();

    # Provision the instance
    my $instance = $provider->create_instance(check_connectivity => 0);
    $startup_timings->{ssh_access} = $instance->check_ssh_port(timeout => 300);

    my ($systemd_analyze, $systemd_blame) = do_systemd_analyze($instance);
    $startup_timings->{$_} = $systemd_analyze->{$_} foreach (keys(%{$systemd_analyze}));
    $blame_timings->{first} = $systemd_blame;

    # Collect kernel version
    $tags->{os_kernel_release} = $instance->run_ssh_command(cmd => 'uname -r');
    $tags->{os_kernel_version} = $instance->run_ssh_command(cmd => 'uname -v');

    # Do soft reboot
    my ($shutdown_time, $startup_time) = $instance->softreboot();
    $startup_timings->{ssh_access_soft} = $startup_time;

    ($systemd_analyze, $systemd_blame) = do_systemd_analyze($instance);
    $startup_timings->{$_ . '_soft'} = $systemd_analyze->{$_} foreach (keys(%{$systemd_analyze}));
    $blame_timings->{soft} = $systemd_blame;

    # Do hard reboot
    $instance->stop();
    $startup_timings->{ssh_access_hard} = $instance->start();

    ($systemd_analyze, $systemd_blame) = do_systemd_analyze($instance);
    $startup_timings->{$_ . '_hard'} = $systemd_analyze->{$_} foreach (keys(%{$systemd_analyze}));
    $blame_timings->{hard} = $systemd_blame;

    # Do logging to openqa UI
    my $msg = "Bootup timeings:$/";
    for my $key (sort(keys(%{$startup_timings}))) {
        $msg .= sprintf("%-16s => %s$/", $key, $startup_timings->{$key});
    }
    record_info("RESULTS", $msg);

    # Store values in influx-db
    my $url = get_var('PUBLIC_CLOUD_PERF_DB_URI');
    if ($url) {
        my $data = {
            table  => 'bootup',
            tags   => $tags,
            values => $startup_timings
        };
        influxdb_push_data($url, 'publiccloud', $data);

        for my $type (qw(first soft hard)) {
            $tags->{boottype} = $type;
            $data = {
                table  => 'bootup_blame',
                tags   => $tags,
                values => $blame_timings->{$type}
            };
            influxdb_push_data($url, 'publiccloud', $data);
        }
    }

    # Validate bootup timing against hard limits
    for my $key (keys(%{$thresholds})) {
        my $limit = $thresholds->{$key};
        my $value = $startup_timings->{$key};
        die("Missing measurment $key") unless (defined($value));
        if ($value > $limit) {
            record_info('ERROR', "$key:$value exceed limit of $limit", result => 'fail');
            $self->result('fail');
        }
    }
}

1;

=head1 Discussion

This module collect boot time statistics from publiccloud images.
It collect systemd_analyze and ssh access time for three states:
1) After first deployment
2) After a soft reboot
3) After hard reboot

All values are stored in a influx db.

=head1 Configuration

=head2 PUBLIC_CLOUD_PERF_DB_URI

Optional variable. If set, the bootup times get stored in the influx
database. The database name is 'publiccloud'.
(e.g. PUBLIC_CLOUD_PERF_DB_URI=http://openqa-perf.qa.suse.de:8086)

=cut
