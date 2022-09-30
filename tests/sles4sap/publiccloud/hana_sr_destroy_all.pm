# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Deploy SAP Hana cluster with system replication and verify working cluster.

package hana_sr_destroy_all;

use base 'sles4sap_publiccloud_basetest';
use strict;
use warnings FATAL => 'all';
use testapi;

sub test_flags {
    return {
        fatal => 1
    };
}

sub run {
    record_info("Performing cleanup")
}

1;