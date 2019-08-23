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
# - Check firewalld status by running "firewall-cmd --state"
# - Or check SuSEfirewall2 status by running "SuSEfirewall2 status"
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: fate#323436

use base 'consoletest';
use strict;
use warnings;
use testapi;
use version_utils "is_upgrade";

sub run {
    my ($self) = @_;
    if ($self->firewall eq 'firewalld') {
        my $ret = script_run('firewall-cmd --state');
        if ($ret && is_upgrade && get_var('HDD_1') =~ /\b(1[123]|42)[\.-]/) {
            # In case of upgrades from SFW2-based distros (Leap < 15.0 to TW) we end up without
            # any firewall
            record_soft_failure "boo#1144543 - Migration from SFW2 to firewalld: no firewall enabled";
            $ret = 0;
        }
        if ($ret == 0) {
            $self->result('ok');
        }
        else {
            $self->result('fail');
        }
    }
    else {
        assert_script_run('SuSEfirewall2 status');
    }
}

1;
