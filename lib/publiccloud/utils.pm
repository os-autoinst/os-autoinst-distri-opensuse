# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Public cloud utilities
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

package publiccloud::utils;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use utils;
use version_utils;

our @EXPORT = qw(select_host_console);


# Select console on the test host, regardless of the TUNNELED variable.
sub select_host_console() {
    if (check_var('TUNNELED', '1')) {
        select_console('tunnel-console');
    } else {
        select_console('root-console');
    }
}

1;
