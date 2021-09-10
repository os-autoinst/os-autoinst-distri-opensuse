# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
