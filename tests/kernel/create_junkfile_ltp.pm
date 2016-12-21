# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Creates some files for the aiodio tests, see ltp/testscripts/ltp-aiodio.sh
# Maintainer: Richard Palethorpe <rpalethorpe@suse.com>

use 5.018;
use warnings;
use base 'opensusebasetest';
use testapi;

sub run {
    my ($self) = @_;
    my $pdir   = '$TMPDIR/aiodio.$$';
    my $dir    = '$TMPDIR/aiodio';

    assert_script_run("mkdir -p $pdir/junkdir $dir");
    assert_script_run("dd if=/dev/urandom of=$pdir/junkfile oflag=sync bs=1M count=26");
    upload_logs("$pdir/junkfile", failok => 1);
    for my $f (['f', '8K'], ['1', '4K'], ['2', '1K'], ['3', '512']) {
        assert_script_run("dd if=$pdir/junkfile of=$pdir/ff$f->[0] bs=$f->[1] conv=block,sync");
    }
    for my $f ([2, '2K'], [3, '1K'], [4, '512'], [5, '4K']) {
        assert_script_run("dd if=$pdir/junkfile of=$dir/file$f->[0] bs=$f->[1] conv=block,sync");
    }
}

sub test_flags {
    return {
        fatal     => 1,
        milestone => 1
    };
}

=head1 Configuration

This test module is activated when LTP_COMMAND_FILE is set to one of the aiodio
tests.

=cut

1;
