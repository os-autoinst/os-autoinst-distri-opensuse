# openssl fips test
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Stronger password to be used with CC/FIPS.
#
# Maintainer: QE Security <none@suse.de>

package security::config;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT = qw(strong_password);

=head2 strong_password

    $security::config:strong_password;

This will return a strong, FIPS compliant password to be used, for example,
during installation when setting the Common Criteria password on SLES 15-SP6+.
=cut

our $strong_password = "not-so-s3cr3t_BUT_VERY_STRONG.";

1;
