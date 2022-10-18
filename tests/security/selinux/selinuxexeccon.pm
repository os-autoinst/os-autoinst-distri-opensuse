# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test '# selinuxexeccon' command works,
#          report process context for command from the current context
# Maintainer: QE Security <none@suse.de>
# Tags: poo#105202, tc#1769801

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my ($self) = @_;

    select_serial_terminal;

    # Report the SELinux process context for this command from the current context
    validate_script_output('selinuxexeccon /usr/bin/passwd', sub { m/.*_u:.*_r:.*_t:s.*:c.*/ });
}

1;
