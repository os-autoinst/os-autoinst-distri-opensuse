# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Set MAINT_TEST_REPO to the content of INCIDENT_REPO when
#          MAINT_TEST_REPO has not been set. Intended to be used only
#          in Single Incident job groups.
# Maintainer: QE SAP & HA <qe-sap@suse.de>

use base "opensusebasetest";
use testapi;

sub run {
    set_var('MAINT_TEST_REPO', get_var('INCIDENT_REPO', '')) unless get_var('MAINT_TEST_REPO');
}

1;
