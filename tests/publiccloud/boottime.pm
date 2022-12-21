# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Collect/store bootup time from publiccloud instances.
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'publiccloud::basetest';
use Mojo::Util 'trim';
use Data::Dumper;
use testapi;
use db_utils;
use publiccloud::ssh_interactive qw(select_host_console);

our $default_analyze_thresholds = {
    # First boot after provisioning
    kernel => 15,
    userspace => 60,
    initrd => 20,
    overall => 120,
    ssh_access => 60,

    # Values after soft reboot
    kernel_soft => 15,
    userspace_soft => 60,
    initrd_soft => 10,
    overall_soft => 120,
    ssh_access_soft => 70,

    # Values after hard reboot
    kernel_hard => 15,
    userspace_hard => 60,
    initrd_hard => 10,
    overall_hard => 120,
    ssh_access_hard => 60,
};

our $default_azure_analyze_thresholds = {
    %{$default_analyze_thresholds},
    userspace => 160,
    overall => 180,
};

our $default_azure_BYOS_analyze_thresholds = {
    %{$default_analyze_thresholds},
    userspace => 100,
};

our $default_ec2_analyze_thresholds = {
    %{$default_analyze_thresholds},
    userspace => 90,
};

our $default_gce_BYOS_analyze_thresholds = {
    %{$default_analyze_thresholds},
    userspace => 40,
    overall => 60,
};

our $default_gce_analyze_thresholds = {
    %{$default_analyze_thresholds},
    userspace => 80,
};

our $default_blame_thresholds = {
    first => {'wicked.service' => 20},
    soft => {'wicked.service' => 20},
    hard => {'wicked.service' => 20},
};


our $thresholds_by_flavor = {
    # Azure
    'Azure-BYOS' => {
        analyze => $default_azure_BYOS_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'Azure-BYOS-gen2' => {
        analyze => $default_azure_BYOS_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'Azure-CHOST-BYOS' => {
        analyze => $default_azure_BYOS_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'Azure-Basic' => {
        analyze => $default_azure_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'Azure-Basic-gen2' => {
        analyze => $default_azure_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'Azure-Standard' => {
        analyze => $default_azure_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'Azure-Standard-gen2' => {
        analyze => $default_azure_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'AZURE-Basic-Updates' => {
        analyze => $default_azure_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'AZURE-Basic-gen2-Updates' => {
        analyze => $default_azure_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'Azure-Standard-Updates' => {
        analyze => $default_azure_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'AZURE-Standard-gen2-Updates' => {
        analyze => $default_azure_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'AZURE-Standard-Updates' => {
        analyze => $default_azure_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'AZURE-BYOS-Updates' => {
        analyze => $default_azure_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'AZURE-BYOS-gen2-Updates' => {
        analyze => $default_azure_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'Azure-Image-Updates' => {
        analyze => $default_azure_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'Azure-Image-Updates' => {
        analyze => $default_azure_analyze_thresholds,
        blame => $default_blame_thresholds,
    },

    # EC2
    'EC2-CHOST-BYOS' => {
        analyze => $default_analyze_thresholds,
        blame => $default_blame_thresholds,
    },

    'EC2-CHOST-BYOS' => {
        analyze => $default_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    EC2 => {
        analyze => $default_ec2_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'EC2-ARM' => {
        analyze => $default_ec2_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'EC2-BYOS' => {
        analyze => $default_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'EC2-BYOS-Image-Updates' => {
        analyze => $default_ec2_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'EC2-BYOS-Updates' => {
        analyze => $default_ec2_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'EC2-Updates' => {
        analyze => $default_ec2_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'EC2-ARM-Updates' => {
        analyze => $default_ec2_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'EC2-BYOS-ARM-Updates' => {
        analyze => $default_ec2_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'EC2-Image-Updates' => {
        analyze => $default_ec2_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'EC2-BYOS-ARM-Image-Updates' => {
        analyze => $default_ec2_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'EC2-ARM-Image-Updates' => {
        analyze => $default_ec2_analyze_thresholds,
        blame => $default_blame_thresholds,
    },

    # GCE
    GCE => {
        analyze => $default_gce_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'GCE-Updates' => {
        analyze => $default_gce_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'GCE-BYOS' => {
        analyze => $default_gce_BYOS_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'GCE-BYOS-Updates' => {
        analyze => $default_gce_BYOS_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'GCE-CHOST-BYOS' => {
        analyze => $default_gce_BYOS_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'GCE-Image-Updates' => {
        analyze => $default_gce_BYOS_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
    'GCE-BYOS-Image-Updates' => {
        analyze => $default_gce_BYOS_analyze_thresholds,
        blame => $default_blame_thresholds,
    },
};


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
    my $res = {};
    ($string) = split(/\r?\n/, $string, 2);
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
    my $ret = {};
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
    my $output = "";
    my @ret;

    # Wait for guest register, before calling syastemd-analyze
    $instance->wait_for_guestregister();
    while ($output !~ /Startup finished in/ && time() - $start_time < $args{timeout}) {
        $output = $instance->run_ssh_command(cmd => 'systemd-analyze time', proceed_on_failure => 1);
        sleep 5;
    }

    die("Unable to get system-analyze in $args{timeout} seconds") unless (time() - $start_time < $args{timeout});
    push @ret, extract_analyze($output);

    $output = $instance->run_ssh_command(cmd => 'systemd-analyze blame');
    push @ret, extract_blame($output);

    return @ret;
}

sub measure_timings {
    my ($self, $args) = @_;
    my $provider;
    my $instance;

    my $ret = {
        kernel_release => undef,
        kernel_version => undef,
        analyze => {},
        blame => {
            first => {}, soft => {}, hard => {}
        },
    };

    if (get_var('PUBLIC_CLOUD_QAM')) {
        $instance = $args->{my_instance};
        $provider = $args->{my_provider};
    } else {
        $provider = $self->provider_factory();
        $instance = $self->{my_instance} = $provider->create_instance(check_connectivity => 0);
    }

    $ret->{analyze}->{ssh_access} = $instance->wait_for_ssh(timeout => 300);
    assert_script_run(sprintf('ssh-keyscan %s >> ~/.ssh/known_hosts', $instance->public_ip));

    my ($systemd_analyze, $systemd_blame) = do_systemd_analyze($instance);
    $ret->{analyze}->{$_} = $systemd_analyze->{$_} foreach (keys(%{$systemd_analyze}));
    $ret->{blame}->{first} = $systemd_blame;

    # Collect kernel version
    $ret->{kernel_release} = $instance->run_ssh_command(cmd => 'uname -r');
    $ret->{kernel_version} = $instance->run_ssh_command(cmd => 'uname -v');

    # Do soft reboot
    my ($shutdown_time, $startup_time) = $instance->softreboot();
    $ret->{analyze}->{ssh_access_soft} = $startup_time;

    ($systemd_analyze, $systemd_blame) = do_systemd_analyze($instance);
    $ret->{analyze}->{$_ . '_soft'} = $systemd_analyze->{$_} foreach (keys(%{$systemd_analyze}));
    $ret->{blame}->{soft} = $systemd_blame;

    # Do hard reboot
    $instance->stop();
    $ret->{analyze}->{ssh_access_hard} = $instance->start();

    ($systemd_analyze, $systemd_blame) = do_systemd_analyze($instance);
    $ret->{analyze}->{$_ . '_hard'} = $systemd_analyze->{$_} foreach (keys(%{$systemd_analyze}));
    $ret->{blame}->{hard} = $systemd_blame;

    # Do logging to openqa UI
    $Data::Dumper::Sortkeys = 1;
    record_info("RESULTS", Dumper($ret));

    $instance->run_ssh_command(cmd => 'sudo tar -czvf /tmp/sle_cloud.tar.gz /var/log/cloudregister /var/log/cloud-init.log /var/log/cloud-init-output.log /var/log/messages /var/log/NetworkManager', proceed_on_failure => 1);
    $instance->upload_log('/tmp/sle_cloud.tar.gz');

    return $ret;
}

sub store_in_db {
    my ($self, $results) = @_;
    my $url = get_var('PUBLIC_CLOUD_PERF_DB_URI');
    return unless ($url);
    my $db = get_var('PUBLIC_CLOUD_PERF_DB', 'perf');
    my $token = get_required_var('_PUBLIC_CLOUD_PERF_DB_TOKEN');
    my $org = get_var('PUBLIC_CLOUD_PERF_DB_ORG', 'qec');

    my $tags = {
        instance_type => get_required_var('PUBLIC_CLOUD_INSTANCE_TYPE'),
        os_flavor => get_required_var('FLAVOR'),
        os_version => get_required_var('VERSION'),
        os_build => get_required_var('BUILD'),
        os_kernel_release => $results->{kernel_release},
        os_kernel_version => $results->{kernel_version},
    };

    $tags->{os_pc_build} = get_var('PUBLIC_CLOUD_QAM') ? 'N/A' : get_required_var('PUBLIC_CLOUD_BUILD');
    $tags->{os_pc_kiwi_build} = get_var('PUBLIC_CLOUD_QAM') ? 'N/A' : get_required_var('PUBLIC_CLOUD_BUILD_KIWI');

    # Store values in influx-db
    my $data = {
        table => 'bootup',
        tags => $tags,
        values => $results->{analyze}
    };
    influxdb_push_data($url, $db, $org, $token, $data);

    for my $type (qw(first soft hard)) {
        $tags->{boottype} = $type;
        $data = {
            table => 'bootup_blame',
            tags => $tags,
            values => $results->{blame}->{$type}
        };
        influxdb_push_data($url, $db, $org, $token, $data);
    }
}

sub check_threshold_values
{
    my ($self, $results, $thresholds) = @_;

    for my $key (keys(%{$thresholds})) {
        my $limit = $thresholds->{$key};
        my $value = $results->{$key};
        die("Missing measurment $key") unless (defined($value));
        if ($value > $limit) {
            record_info('ERROR', "$key:$value exceed limit of $limit", result => 'fail');
            $self->result('fail');
        }
    }
}

sub check_thresholds {
    my ($self, $results) = @_;

    my $flavor = get_required_var('FLAVOR');
    die("Missing thresholds for flavor $flavor") unless (exists($thresholds_by_flavor->{$flavor}));
    my $thresholds = $thresholds_by_flavor->{$flavor};
    $Data::Dumper::Sortkeys = 1;
    record_info("THRESHOLDS", Dumper($thresholds));

    $self->check_threshold_values($results->{analyze}, $thresholds->{analyze});
    for my $type (qw(first soft hard)) {
        $self->check_threshold_values($results->{blame}->{$type}, $thresholds->{blame}->{$type});
    }
}

sub run {
    my ($self, $args) = @_;
    select_host_console();

    my $results = $self->measure_timings($args);
    $self->store_in_db($results) if (check_var('_PUBLIC_CLOUD_PERF_PUSH_DATA', 1));
    $self->check_thresholds($results);
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
