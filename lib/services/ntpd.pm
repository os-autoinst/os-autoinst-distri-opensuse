# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Package for ntp service tests
#
# Maintainer: Alynx Zhou <alynx.zhou@suse.com>

package services::ntpd;
use base 'opensusebasetest';
use testapi;
use utils;
use strict;
use warnings;

# default ntp service type and name
my $service_type = 'Systemd';
my $service_name = 'ntpd';

sub install_service {
    zypper_call('in ntp');
}

sub remove_service {
    zypper_call('rm ntp');
}

# This will be used by QAM ntp test.
sub check_config {
    my $server_count = script_output 'ntpq -p | tail -n +3 | wc -l';
    record_info 'Servers', "Default ntp servers defined: $server_count";
    assert_script_run 'cp /etc/ntp.conf /etc/ntp.conf.bkp';
    assert_script_run 'echo "server 172.16.12.34" >> /etc/ntp.conf';
    assert_script_run 'echo "server 172.16.21.43" >> /etc/ntp.conf';
    common_service_action($service_name, $service_type, 'restart');
    assert_script_run 'ntpq -p';
    for (my $i = 0; $i < 5; $i++) {
        if ($server_count + 2 <= script_output('ntpq -pn | tail -n +3 | wc -l')) {
            return;
        }
        sleep 30;
    }
    die "Configuration not loaded";
}

sub config_service {
    assert_script_run("echo 'server ntp1.suse.de iburst' >> /etc/ntp.conf");
    assert_script_run("echo 'server ntp2.suse.de iburst' >> /etc/ntp.conf");
}

sub enable_service {
    common_service_action($service_name, $service_type, 'enable');
}

sub disable_service {
    common_service_action($service_name, $service_type, 'disable');
}

sub start_service {
    common_service_action($service_name, $service_type, 'start');
}

sub stop_service {
    common_service_action($service_name, $service_type, 'stop');
}

sub check_service {
    common_service_action($service_name, $service_type, 'is-active');
    common_service_action($service_name, $service_type, 'is-enabled');
}

sub check_function {
    assert_script_run("date -s 'Tue Jul 03 10:42:42 2018'");
    assert_script_run("date | grep 2018");
    common_service_action($service_name, $service_type, 'restart');
    script_retry('ntpq -pn | grep "^[+\|*]"', delay => 30, retry => 24);
    assert_script_run("date | grep -v 2018");
}

# Check ntp service before and after migration.
# Stage is 'before' or 'after' system migration.
sub full_ntpd_check {
    my (%hash) = @_;
    my ($stage, $type) = ($hash{stage}, $hash{service_type});
    $service_type = $type;
    $service_name = ($service_type eq 'SystemV') ? 'ntp' : 'ntpd';
    if ((get_var('ORIGIN_SYSTEM_VERSION') eq '11-SP4') || $stage eq 'before') {
        install_service();
        config_service();
        enable_service();
        start_service();
    }
    check_service();
    check_function();
}

1;
