# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deployment steps for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use qesapdeployment;

sub wait_for_ssh {
    my ($host) = @_;
    my $timeout //= bmwqemu::scale_timeout(600);
    my $start_time = time();
    my $check_port = 1;

    # Looping until reaching timeout or passing two conditions :
    # - SSH port 22 is reachable
    # - journalctl got message about reaching one of certain targets
    while ((my $duration = time() - $start_time) < $timeout) {
        if ($check_port) {
            $check_port = 0 if (script_run('nc -vz -w 1 ' . $host . ' 22', quiet => 1) == 0);
        }
        else {
            return $duration;
        }
        sleep 5;
    }
    die 'Timed out while waiting for ssh to be available in the CSP instances';
}

sub run {
    my $ret = qesap_execute(cmd => 'terraform', verbose => 1, timeout => 1800);
    die "'qesap.py terraform' return: $ret" if ($ret);
    my $inventory = qesap_get_inventory(get_required_var('PUBLIC_CLOUD_PROVIDER'));
    upload_logs($inventory, failok => 1);
    my @remote_ips = qesap_remote_hana_public_ips;
    record_info 'Remote IPs', join(' - ', @remote_ips);
    foreach my $host (@remote_ips) { wait_for_ssh $host; }
    $ret = qesap_execute(cmd => 'ansible', cmd_options => '--profile', verbose => 1, timeout => 3600);
    die "'qesap.py ansible' return: $ret" if ($ret);
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_upload_logs();
    my $prov = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my $inventory = qesap_get_inventory($prov);
    if (script_run("test -e $inventory") == 0)
    {
        # sleep bmwqemu::scale_timeout(300)
        foreach my $element (
            ['crm status', 'crm_status.txt'],
            ['crm configure show', 'crm_configure.txt'],
            ['lsblk -i -a', 'lsblk.txt'],
            ['journalctl -b --no-pager -o short-precise', 'journalctl.txt'],
            ['systemctl --no-pager --full status sbd', 'sbd.txt']) {
            my $out = qesap_ansible_script_output(cmd => @$element[0], provider => $prov, filter => 'hana', failok => 1);
            save_tmp_file(@$element[1], $out);
        }
        qesap_execute(cmd => 'ansible', cmd_options => '-d', verbose => 1, timeout => 300);
    }
    qesap_execute(cmd => 'terraform', cmd_options => '-d', verbose => 1, timeout => 1200);
    $self->SUPER::post_fail_hook;
}

1;
