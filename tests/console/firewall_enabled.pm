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
use warnings;
use testapi;

sub run {
    my ($self) = @_;
    if ($self->firewall eq 'firewalld') {
        assert_script_run('firewall-cmd --state');
    }
    else {
        assert_script_run('SuSEfirewall2 status');
    }
}

1;
