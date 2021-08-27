# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Regression test for btrfsmaintenance. poo#59211.
#   Fixed by commit 93b0054 (Make balance, scrub, and trim mutually exclusive tasks)
# Maintainer: An Long <lan@suse.com>
use strict;
use warnings;
use base 'opensusebasetest';
use File::Basename;
use testapi;
use utils;
use power_action_utils 'power_action';

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Reinstall btrfsmaintenance pachage
    zypper_call 'in -f btrfsmaintenance';

    assert_script_run('cd /usr/share/btrfsmaintenance');
    script_output('
for i in $(seq 1 10)
do
{
./btrfs-defrag.sh;
./btrfs-scrub.sh;
./btrfs-trim.sh;
./btrfs-balance.sh;
}&
done
');

}

1;

