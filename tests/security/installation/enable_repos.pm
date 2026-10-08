# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: After installation, enable all repository on a Full flavor system.
# Maintainer: QE Security <none@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use utils 'zypper_call';
use Utils::Architectures qw(is_ppc64le is_s390x);
use version_utils 'is_agama';
use serial_terminal 'select_serial_terminal';

sub run {
    is_ppc64le() ? select_console('root-console') : select_serial_terminal();
    return unless check_var('FLAVOR', 'Full-QR') || check_var('FLAVOR', 'Full');
    zypper_call('mr -e -a');

    # On s390x the Full medium is not attached as a DVD, Agama installs from
    # inst.install_url instead and no longer copies that agama-N repository
    # to the target (bsc#1264277), so add it back.
    return unless is_s390x && is_agama && check_var('FLAVOR', 'Full');
    my $install_url = get_required_var('INST_INSTALL_URL');
    $install_url .= '/$basearch' if get_var('SPLIT_REPODATA');
    zypper_call("ar -c '$install_url' Installation");
    zypper_call('--gpg-auto-import-keys ref');
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
