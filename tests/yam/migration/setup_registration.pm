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
use registration 'register_addons_cmd';

sub run {
    my @addons = split(/,/, get_required_var('SCC_ADDONS'));
    my @addons_drop = split(/,/, get_var('SCC_ADDONS_DROP'));
    my %filter;
    @filter{@addons_drop} = {};

    select_console('root-console');
    assert_script_run('SUSEConnect -d');
    assert_script_run('SUSEConnect --debug --cleanup');
    assert_script_run('SUSEConnect --debug --regcode ' . get_required_var('SCC_REGCODE'), 200);
    my $addons_to_register = join(',', grep !exists $filter{$_}, @addons);
    register_addons_cmd($addons_to_register);
}

1;
