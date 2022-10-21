# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Update TrouSerS and tpm-tools to the latest version
#          Make sure your setup has a TPM 1.2 device attached,
#          both hardware or software devices should be fine
#          We need only test this feature on aarch64 platform,
#          However, based on bsc#1193350, test it on x86_64 as
#          well
# Maintainer: QE Security <none@suse.de>
# Tags: poo#103644, tc#1769832

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call systemctl package_upgrade_check);
use Utils::Architectures;

sub run {
    select_serial_terminal;

    # Version check
    my $pkg_list = {'tpm-tools' => '1.3.9.2', trousers => '0.3.15'};
    zypper_call("in " . join(' ', keys %$pkg_list));
    package_upgrade_check($pkg_list);

    # Based on bsc#1193350, swtpm 1.2 device is not supported
    # on arch64 platform any more, so skip the test on aarch64
    if (!is_aarch64) {
        # Make sure tpm device can be created
        assert_script_run('ls -l /dev/tpm*');

        # Make sure 'tcsd' service can be enabled and started successfully
        systemctl('enable tcsd');
        systemctl('start tcsd');
        systemctl('is-active tcsd');

        # Make sure TPM 1.2 device can be recognized and selftest succeeded
        validate_script_output('tpm_version', sub { m/TPM 1.2 Version/ });
        validate_script_output('tpm_selftest -l debug', sub { m/tpm_selftest succeeded/ });
    }
}

sub post_fail_hook {
    script_run('dmesg > /var/tmp/dmesg.txt');
    upload_logs('/var/tmp/dmesg.txt');
}

1;
