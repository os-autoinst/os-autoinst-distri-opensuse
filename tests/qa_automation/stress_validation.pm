# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: base class for kernel regression tests
# Maintainer: Yong Sun <yosun@suse.com>

package stress_validation;
use base "qa_run";
use strict;
use warnings;

sub test_suite {
    return 'acceptance';
}

sub junit_type {
    return 'stress_validation';
}

1;
