# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: firewalld
# Summary: Ensure firewall is running
# - Check firewalld status by running "firewall-cmd --state"
# - Or check SuSEfirewall2 status by running "SuSEfirewall2 status"
# Maintainer: QE Core <qe-core@suse.de>
# Tags: fate#323436

use base 'consoletest';
use strict;
use warnings;
use testapi;
use version_utils qw(is_upgrade is_jeos is_sle is_vmware is_leap is_tumbleweed);
use serial_terminal 'select_serial_terminal';
use Utils::Architectures;

sub run {
    my ($self) = @_;
    if ($self->firewall eq 'firewalld') {
        if (is_jeos && get_var('FLAVOR', '') =~ /cloud/i) {
            script_run('rpm -q firewalld') or die "Firewalld is pre-installed on Minimal-VM cloud images";
            return;
        }
        assert_script_run("firewall-cmd --version", fail_message => "firewall-cmd is not present");
        if (script_output('firewall-cmd --state', timeout => 60, proceed_on_failure => 1) !~ /running/) {
            if (is_upgrade && get_var('HDD_1') =~ /\b(1[123]|42)[\.-]/) {
                # In case of upgrades from SFW2-based distros (Leap < 15.0 to TW) we end up without any firewall
                record_soft_failure "boo#1144543 - Migration from SFW2 to firewalld: no firewall enabled";
                return;
            } elsif (is_jeos && is_vmware) {
                record_info('No FW', 'MinimalVM\'s VMWare image has firewalld disabled');
            } else {
                die "firewall-cmd is not running";
            }
        }
    } else {
        assert_script_run('SuSEfirewall2 status');
    }
}

1;
