# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: Moo, cause we can
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use testapi;

sub run {
    select_console 'user-console';
    my $expected = <<'EOF';
   \\\\\
  \\\\\\\__o
__\\\\\\\'/_
EOF
    validate_script_output 'zypper moo', sub { $_ eq $expected };
}

1;
