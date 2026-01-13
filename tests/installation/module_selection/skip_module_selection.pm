# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Skip extension and module selection
#          in "Extension and Module Selection" dialog.
# Medium:  Full (Description Text shows "Directory on the Media")
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';

sub run {
    $testapi::distri->get_module_selection()->skip_selection();
}

1;
