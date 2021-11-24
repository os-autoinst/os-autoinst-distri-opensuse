# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Register nonconflicting modules:
# - Containers Module
# - Desktop Application Module
# - Development Tools Module
# - Legacy Module
# - Transactional Server Module
# - Web and Scripting Module
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;

sub run {
    $testapi::distri->get_module_selection()->register_modules(
        [qw(containers desktop development legacy web)]);
}

1;
