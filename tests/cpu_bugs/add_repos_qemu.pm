# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
#
# Summary: Add repo into QEMU
# Maintainer: James Wang <jnwang@suse.com>

use base "consoletest";
use bootloader_setup;
use ipmi_backend_utils;
use power_action_utils 'power_action';
use testapi;
use utils;
use version_utils 'is_sle';
my $cliect_ini_url = get_required_var('CLIENT_INI');
my $worker_ini_url = get_required_var('WORKER_INI');
my $addonurl_hpc = get_required_var('ADDONURL_HPC');
my $addonurl_sdk = get_required_var('ADDONURL_SDK');
sub run {
    my $self = shift;
    #SLE >= 15, we need hpc, sdk modules
    #SLE >= 12, we add these modules during installation, so skip here.
    if (is_sle(">=15")) {
        zypper_call("ar $addonurl_hpc hpc");
        zypper_call("ar $addonurl_sdk sdk");
    }
    zypper_call('--gpg-auto-import-keys ref');
}

1;

