# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Changes the VERSION to HDDVERSION and reload needles.
#       At the beginning of upgrading, we need patch the original
#       system, which is still old version at the moment.
# Maintainer: Qingming Su <qmsu@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;

sub run {
    return unless get_var('UPGRADE');

    #Before upgrading, orginal system version is actually HDDVERSION
    #Save VERSION TO UPGRADE_TARGET_VERSION
    set_var('UPGRADE_TARGET_VERSION', get_var('VERSION'));
    #Switch to orginal system version, which is HDDVERSION
    set_var('VERSION', get_required_var('HDDVERSION'), reload_needles => 1);
}

1;
# vim: set sw=4 et:
