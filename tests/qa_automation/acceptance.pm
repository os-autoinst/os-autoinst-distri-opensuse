# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Second upload of qa_automation/acceptance.pm
# G-Maintainer: Stephan Kulow <coolo@suse.de>

use base "qa_run";
use strict;
use warnings;
use testapi;

sub create_qaset_config {
    # nothing by default
}

sub junit_type {
    return 'stress_validation';
}

sub test_suite {
    return 'acceptance';
}

1;

