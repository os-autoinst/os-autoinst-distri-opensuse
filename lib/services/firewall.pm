# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Package for firewall service tests
#
# On s390x regression test, the reboot_gnome module will fail for firewall
# with this service change, we can make it work.
#
# Maintainer: Huajian Luo <hluo@suse.com>

package services::firewall;
use base 'opensusebasetest';
use testapi;
use utils;
use strict;
use warnings;

my $service      = 'firewalld';
my $service_type = 'Systemd';
my $pkg          = 'SuSEfirewall2';

sub install_service {
    zypper_call('in ' . $pkg);
}

sub susefirewall2_to_firewalld {
    my $timeout = 360;
    $timeout = 1200 if check_var('ARCH', 'aarch64');
    assert_script_run('susefirewall2-to-firewalld -c',                                     timeout => $timeout);
    assert_script_run('firewall-cmd --permanent --zone=external --add-service=vnc-server', timeout => 60);
    # On some platforms such as Aarch64, the 'firewalld restart'
    # can't finish in the default timeout.

    systemctl 'restart firewalld', timeout => $timeout;
    script_run('iptables -S', timeout => $timeout);
    set_var('SUSEFIREWALL2_SERVICE_CHECK', 1);
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
        $pkg     = 'susefirewall2-to-firewalld';
        install_service();
        susefirewall2_to_firewalld();
    }
    check_service();
}

1;

