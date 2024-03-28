# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
#
# Basetest used for Microsoft SDAF deployment

package sles4sap::microsoft_sdaf_basetest;
use strict;
use warnings;
use testapi;
use parent 'opensusebasetest';
use sles4sap::sdaf_library;
use sles4sap::console_redirection;

sub post_fail_hook {
    record_info('Post fail', 'Executing post fail hook');
    # Cleanup SDAF files form Deployer VM
    connect_target_to_serial();
    cleanup_sdaf_files();
    disconnect_target_from_serial();
}

sub post_run_hook {
}

1;
