# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Ensure firewall is running
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: fate#323436

use base 'consoletest';
use strict;
use testapi;
use version_utils qw(:VERSION :SCENARIO);

sub run {
    my ($self) = @_;
    if ($self->firewall eq 'firewalld') {
        if (script_run('firewall-cmd --state') != 0) {
            # soft-fail for leap upgrade scenarios (see poo#46127)
            if (is_upgrade() && is_leap('15.0+')) {
                record_soft_failure 'bsc#1122769';
            } else {
                die "firewalld is not running";
            }
        }
    }
    else {
        assert_script_run('SuSEfirewall2 status');
    }
}

1;
