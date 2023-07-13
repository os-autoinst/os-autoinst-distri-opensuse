# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Package for firewall service tests
#
# On s390x regression test, the reboot_gnome module will fail for firewall
# with this service change, we can make it work.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package services::firewall;
use base 'opensusebasetest';
use testapi;
use utils;
use strict;
use warnings;

my $service = 'firewalld';
my $service_type = 'Systemd';
my $pkg = 'SuSEfirewall2';

sub install_service {
    zypper_call('in ' . $pkg);
}

sub enable_service {
    common_service_action $service, $service_type, 'enable';
}

sub start_service {
    common_service_action $service, $service_type, 'start';
}

# check service is running and enabled
sub check_service {
    common_service_action $service, $service_type, 'is-enabled';
    common_service_action $service, $service_type, 'is-active';
}

# check firewall service before and after migration
# stage is :
#           'before' for SuSEfirewall2 or
#           'after' for firewalld after system migration.
sub full_firewall_check {
    my (%hash) = @_;
    my $stage = $hash{stage};

    # we just support SLE12 to SLES15 SuSEfirewall2 to firewalld check
    return if (get_var('ORIGIN_SYSTEM_VERSION') eq '11-SP4');
    if ($stage eq 'before') {
        $service = 'SuSEfirewall2';
        install_service();
        enable_service();
        start_service();
    } else {
        $service = 'firewalld';
        $pkg = 'susefirewall2-to-firewalld';
        install_service();
        susefirewall2_to_firewalld();
    }
    check_service();
}

1;

