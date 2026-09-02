#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Backward-compatible wrapper for security agnostic tests
#
# Delegates to lib/agnosticTestRunner.pm with domain => 'security'.
# New code should use agnosticTestRunner directly.
#
# Maintainer: QE Security <none@suse.de>

package security::agnosticTestRunner;

use strict;
use warnings;
use agnosticTestRunner;

sub new {
    my ($class, $args) = @_;
    $args->{domain} //= 'security';
    return agnosticTestRunner->new($args);
}

1;
