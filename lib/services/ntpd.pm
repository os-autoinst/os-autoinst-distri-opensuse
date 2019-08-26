# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Package for ntp service tests
#
# Maintainer: Alynx Zhou <alynx.zhou@suse.com>

package services::ntpd;
use base 'opensusebasetest';
use testapi;
use utils;
use strict;
use warnings;

sub install_service {
    zypper_call('in ntp');
}

# This will be used by QAM ntp test.
sub check_config {
    my $server_count = script_output 'ntpq -p | tail -n +3 | wc -l';
    assert_script_run 'echo "server 3.europe.pool.ntp.org" >> /etc/ntp.conf';
    assert_script_run 'echo "server 2.europe.pool.ntp.org" >> /etc/ntp.conf';
    systemctl 'restart ntpd.service';
    assert_script_run 'ntpq -p';
    $server_count + 2 <= script_output 'ntpq -p | tail -n +3 | wc -l' or die "Configuration not loaded";
}

sub config_service {
    assert_script_run("echo 'server ntp1.suse.de iburst' >> /etc/ntp.conf");
    assert_script_run("echo 'server ntp2.suse.de iburst' >> /etc/ntp.conf");
}

sub enable_service {
    systemctl('enable ntpd');
}

sub start_service {
    systemctl('start ntpd');
}

sub stop_service {
    systemctl('stop ntpd');
}

sub check_service {
    systemctl('is-enabled ntpd');
    systemctl('is-active ntpd');
}

sub check_function {
    assert_script_run("date -s 'Tue Jul 03 10:42:42 2018'");
    validate_script_output("date", sub { m/2018/ });
    systemctl("restart ntpd.service");
    sleep(120);
    validate_script_output("date", sub { not m/2018/ });
}

# Check ntp service before and after migration.
# Stage is 'before' or 'after' system migration.
sub full_ntpd_check {
    my ($stage) = @_;
    $stage //= '';
    if ($stage eq 'before') {
        install_service();
        config_service();
        enable_service();
        start_service();
    }
    check_service();
    check_function();
}

1;
