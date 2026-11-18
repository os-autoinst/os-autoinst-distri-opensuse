# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate the ntp servers and chronyc tracking by checking
# - NTP servers are present in /etc/chrony.d/99-installer.conf
# - The system is actively synchronized to an external time source
#   rather than being unsynchronized or relying on its own local clock

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use scheduler qw(get_test_suite_data);

sub run {
    my $test_data = get_test_suite_data();
    select_console 'root-console';

    record_info('00: /etc/resolv.conf', script_output('cat /etc/resolv.conf || echo /etc/resolv.conf not existed'));
    record_info("22: nmcli connection", script_output('nmcli connection show || true'));
    my $ret = script_run('test -s /etc/resolv.conf');
    if ($ret == 0) {
        record_info("11: nmcli connection", script_output('nmcli connection show'));
        record_info("11: ping 2.suse.pool.ntp.org", script_output('ping -c 2 2.suse.pool.ntp.org'));
        record_info('DNS Check', script_output('getent ahostsv4 2.suse.pool.ntp.org 2>&1 || echo "DNS Lookup Failed"'));
        record_info("11: chronyc tracking", script_output('chronyc tracking'));
    } else {
        record_info('DNS Fix', 'resolv.conf missing. Cleaning up duplicate nmcli profiles...');
        script_run('nmcli --fields UUID,DEVICE connection show | awk \'$2=="--" {print $1}\' | xargs -r nmcli connection delete');
        assert_script_run('nmcli connection modify ens4 ipv4.dns 10.0.2.3 ipv4.ignore-auto-dns yes');
        assert_script_run('nmcli device reapply ens4');
        assert_script_run('systemctl restart chronyd');
        record_info('22: /etc/resolv.conf (restored)', script_output('cat /etc/resolv.conf'));
        record_info("22: nmcli connection", script_output('nmcli connection show'));
        record_info('DNS Check', script_output('getent ahostsv4 2.suse.pool.ntp.org 2>&1 || echo "DNS Lookup Failed"'));
        record_info('Chrony Tracking', script_output('chronyc tracking 2>&1 || true'));
        record_info('Chrony Sources', script_output('chronyc sources 2>&1 || true'));
    }

    my $chrony_config = '/etc/chrony.d/99-installer.conf';
    assert_script_run("cat $chrony_config");
    assert_script_run("grep '$_' $chrony_config") foreach @{$test_data->{ntp_servers}};

    assert_script_run('chronyc waitsync 24 0 0 5');

    my $tracking_output = script_output('chronyc -c tracking');
    my @fields = split(/,/, $tracking_output);

    if (@fields >= 2) {
        my $ref_id = $fields[1];
        # 00000000 means unsynced/error; 1F1F0101 means local directive active
        if ($ref_id eq '00000000' || $ref_id eq '1F1F0101') {
            die "NTP synchronization failed: Invalid Reference ID ($ref_id)";
        }
    } else {
        die "Failed to parse Reference ID from 'chronyc -c tracking' output: $tracking_output";
    }
}

1;
