# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: fetch sources from upstream git and build systemd inclusive
#          testsuite
# Maintainer: Thomas Blume <tblume@suse.com>


use base "opensusebasetest";

use strict;
use warnings;
use known_bugs;
use testapi;
use power_action_utils 'power_action';
use utils 'zypper_call';
use version_utils qw(is_opensuse is_sle is_tumbleweed);


sub installandbuild {
    zypper_call 'in osc';
    assert_script_run "osc branch openSUSE:Factory systemd";

}
