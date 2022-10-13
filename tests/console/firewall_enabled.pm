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
use Utils::Architectures;

sub run {
    my ($self) = @_;
    if ($self->firewall eq 'firewalld') {
        my $timeout = 30;
        $timeout = 60 if is_ppc64le;
        my $ret = script_run('firewall-cmd --state', timeout => $timeout);
        if ($ret && is_upgrade && get_var('HDD_1') =~ /\b(1[123]|42)[\.-]/) {
            # In case of upgrades from SFW2-based distros (Leap < 15.0 to TW) we end up without
            # any firewall
            record_soft_failure "boo#1144543 - Migration from SFW2 to firewalld: no firewall enabled";
            $ret = 0;
        }
        if ($ret == 0) {
            $self->result('ok');
        } elsif (is_jeos && is_vmware && (is_tumbleweed || is_sle('15-SP4+') || is_leap('15.4+'))) {
            record_info('Expected', 'Starting with sle15sp4\'s QR1 JeOS vmware image, firewalld is disabled by default');
        }
        else {
            $self->result('fail');
        }
    }
    else {
        assert_script_run('SuSEfirewall2 status');
    }
}

1;
