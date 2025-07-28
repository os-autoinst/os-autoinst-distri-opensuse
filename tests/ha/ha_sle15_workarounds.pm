# SUSE's openQA tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Add some SLE15 workarounds
#          Should be removed after SLE15 will be released!
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.com>

use base 'haclusterbasetest';
use version_utils 'is_sle';
use testapi;
use hacluster;

# Do some stuff that need to be workaround in SLE15
sub run {
    return unless is_sle('15+');

    # Modify the device number if needed
    if ((get_var('ISO', '') eq '') && (get_var('ISO_1', '') ne '')) {
        assert_script_run "sed -i 's;sr1;sr0;g' /etc/zypp/repos.d/*";
    }
}

1;
