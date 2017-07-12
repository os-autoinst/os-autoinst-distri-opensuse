# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Moo, cause we can
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "consoletest";
use strict;
use testapi;

sub run {
    select_console 'user-console';
    validate_script_output 'zypper moo', sub {
        <<'EOF'
   \\\\\
  \\\\\\\__o
__\\\\\\\'/_
EOF
    };
}

1;
# vim: set sw=4 et:
