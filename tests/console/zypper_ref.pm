# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: zypper
# Summary: Ensure zypper can refresh repos and enable them if the install
# medium used was a dvd
# - Enable install dvd
# - Import gpg keys and refresh repositories
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils qw(zypper_call zypper_enable_install_dvd);
use version_utils 'is_sle';

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    zypper_enable_install_dvd;
    zypper_call '--gpg-auto-import-keys ref';
}

sub test_flags {
    return {milestone => 1};
}

1;
