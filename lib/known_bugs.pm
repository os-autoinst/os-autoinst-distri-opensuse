# Copyright (C) 2015-2018 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

package known_bugs;

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;
use main_common;
use version_utils;

our @EXPORT = qw(
  create_list_of_serial_failures
  upload_journal
);

sub create_list_of_serial_failures {
    my $serial_failures = [];

    # To add a known bug simply copy and adapt the following line:
    # push @$serial_failures, {type => soft/hard, message => 'Errormsg', pattern => quotemeta 'ErrorPattern' }


    # Detect rogue workqueue lockup
    push @$serial_failures, {type => 'soft', message => 'rogue workqueue lockup bsc#1126782', pattern => quotemeta 'BUG: workqueue lockup'};

    # Detect bsc#1093797 on aarch64
    if (is_sle('=12-SP4') && check_var('ARCH', 'aarch64')) {
        push @$serial_failures, {type => 'hard', message => 'bsc#1093797', pattern => quotemeta 'Internal error: Oops: 96000006'};
    }

    push @$serial_failures, {type => 'soft', message => 'bsc#1103199', pattern => qr/serial-getty.*service: Service hold-off time over, scheduling restart/};

    if (is_kernel_test()) {
        my $type = is_ltp_test() ? 'soft' : 'hard';
        push @$serial_failures, {type => $type, message => 'Kernel Ooops found',             pattern => quotemeta 'Oops:'};
        push @$serial_failures, {type => $type, message => 'Kernel BUG found',               pattern => qr/kernel BUG at/i};
        push @$serial_failures, {type => $type, message => 'WARNING CPU in kernel messages', pattern => quotemeta 'WARNING: CPU'};
        push @$serial_failures, {type => $type, message => 'Kernel stack is corrupted',      pattern => quotemeta 'stack-protector: Kernel stack is corrupted'};
        push @$serial_failures, {type => $type, message => 'Kernel BUG found',               pattern => quotemeta 'BUG: failure at'};
        push @$serial_failures, {type => $type, message => 'Kernel Ooops found',             pattern => quotemeta '-[ cut here ]-'};
    }


    # Disable CPU soft lockup detection on aarch64 until https://progress.opensuse.org/issues/46502 get resolved
    push @$serial_failures, {type => 'hard', message => 'CPU soft lockup detected', pattern => quotemeta 'soft lockup - CPU'} unless check_var('ARCH', 'aarch64');

    return $serial_failures;
}

sub create_list_of_journal_failures {
    my $journal_failures = [];

    # type=soft will force the testmodule result to softfail
    # type=hard will just emit a soft fail message but the module will do a normal fail

    # To add a known bug simply copy and adapt the following line:
    # push @$serial_failures, {type => soft/hard, message => 'Errormsg', pattern => quotemeta 'ErrorPattern' }

    return $journal_failures;
}

sub upload_journal {
    my ($file) = @_;

    my $failures = create_list_of_journal_failures();

    $file = upload_logs($file);

    my $die = 0;
    my %regexp_matched;
    # loop line by line
    open(my $journal, '<', "ulogs/$file") or die("Could not open uploaded journal: $file");
    while (my $line = <$journal>) {
        chomp $line;
        for my $regexp_table (@{$failures}) {
            my $regexp  = $regexp_table->{pattern};
            my $message = $regexp_table->{message};
            my $type    = $regexp_table->{type};

            # Input parameters validation
            die "Wrong type defined for journal failure. Only 'soft' or 'hard' allowed. Got: $type" if $type !~ /^soft|hard|fatal$/;
            die "Message not defined for journal failure for the pattern: '$regexp', type: $type" if !defined $message;

            # If you want to match a simple string please be sure that you create it with quotemeta
            if (!exists $regexp_matched{$regexp} and $line =~ /$regexp/) {
                $regexp_matched{$regexp} = 1;
                my $fail_type = 'softfail';
                if ($type eq 'hard') {
                    record_soft_failure $message. "\n\n" . "$line";
                }
                elsif ($type eq 'soft') {
                    force_soft_failure $message. "\n\n" . "$line";
                }
            }
        }
    }
    close($journal);
}

1;
