# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Initialize LVM volume groups for LTP LVM tests
# Maintainer: Martin Doucha <mdoucha@suse.cz>

use 5.018;
use warnings;
use base 'opensusebasetest';
use testapi;

sub run {
    my ($self) = @_;

    assert_script_run("prepare_lvm.sh", timeout => 300);
}

sub test_flags {
    return {
        fatal     => 1,
        milestone => 1,
    };
}

=head1 Configuration

This test module is activated when LTP_COMMAND_FILE is set to lvm.local

=cut

1;
