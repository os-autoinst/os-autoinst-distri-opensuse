# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Register JeOS and install Server-like modules
# Maintainer: Michal Nowak <mnowak@suse.com>

use base 'opensusebasetest';
use strict;
use testapi;
use utils 'zypper_call';

sub run {
    my $scccode = get_required_var('SCC_REGCODE');
    my $url     = get_required_var('SCC_URL');
    my $arch    = get_required_var('ARCH');
    my $version = get_required_var('VERSION');

    # Register SLES
    assert_script_run "SUSEConnect --url=$url -r $scccode";
    assert_script_run 'SUSEConnect --list-extensions';
    # Install Server-like modules
    for my $module ('basesystem', 'scripting', 'legacy') {
        assert_script_run "SUSEConnect -p sle-module-$module/$version/$arch";
    }
    # Make sure repositories are resolvable
    zypper_call('refresh');
}

1;
# vim: set sw=4 et:
