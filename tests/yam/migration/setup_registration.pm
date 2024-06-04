# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Setup registration before migration.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use utils 'zypper_call';
use registration 'register_addons_cmd';

sub run {
    my @addons = split(/,/, get_required_var('SCC_ADDONS'));
    my @addons_drop = split(/,/, get_var('SCC_ADDONS_DROP'));
    my %filter;
    @filter{@addons_drop} = {};

    select_console('root-console');
    assert_script_run('SUSEConnect --debug --cleanup');
    foreach my $addon (@addons_drop) {
        my $pkg_name = ($addon eq 'ltss') ? "sles-$addon-release" : "sle-module-$addon-release";
        zypper_call("rm $pkg_name");
    }
    assert_script_run('SUSEConnect --debug --regcode ' . get_required_var('SCC_REGCODE'), 200);
    my $addons_to_register = join(',', grep !exists $filter{$_}, @addons);
    register_addons_cmd($addons_to_register);
}

1;
