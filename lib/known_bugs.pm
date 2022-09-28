# Copyright 2015-2018 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package known_bugs;

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;
use Utils::Architectures;
use main_common;
use version_utils;

our @EXPORT = qw(
  create_list_of_serial_failures
  create_list_of_autoinst_failures
  upload_journal
);


=head1 KNOWN_BUGS

=head1 SYNOPSIS

C<use lib::known_bugs>

Allows detection of known errors on the serial console

As we have reocurring problems that can be easily detected on serial level we have decided to detect and show them in opneQA to ease up review and where possible only softfail to not lose the whole test suite

=cut

=head2 create_list_of_serial_failures

Returns the list of known bug patterns on the serial logs
C<my $list = create_list_of_serial_failures();>
This will be used in main.pm to initialize the backend with that list:
C<$testapi::distri->set_expected_serial_failures($list);>

To add a known bug simply copy and adapt the following line:
C<push @$serial_failures, {type => soft/hard, message => 'Errormsg', pattern => quotemeta 'ErrorPattern' }>

=cut

sub create_list_of_serial_failures {
    my $serial_failures = [];


    # Detect rogue workqueue lockup
    push @$serial_failures, {type => 'soft', message => 'rogue workqueue lockup bsc#1126782', pattern => quotemeta 'BUG: workqueue lockup'};

    # Detect bsc#1093797 on aarch64
    if (is_sle('=12-SP4') && is_aarch64) {
        push @$serial_failures, {type => 'hard', message => 'bsc#1093797', pattern => quotemeta 'Internal error: Oops: 96000006'};
    }

    push @$serial_failures, {type => 'soft', message => 'bsc#1103199', pattern => qr/serial-getty.*service: Service hold-off time over, scheduling restart/};

    if (is_kernel_test()) {
        my $type = is_ltp_test() ? 'soft' : 'hard';
        push @$serial_failures, {type => $type, message => 'Kernel Ooops found', pattern => quotemeta 'Oops:'};
        push @$serial_failures, {type => $type, message => 'Kernel BUG found', pattern => qr/kernel BUG at/i};
        push @$serial_failures, {type => $type, message => 'WARNING CPU in kernel messages', pattern => quotemeta 'WARNING: CPU'};
        push @$serial_failures, {type => $type, message => 'Kernel stack is corrupted', pattern => quotemeta 'stack-protector: Kernel stack is corrupted'};
        push @$serial_failures, {type => $type, message => 'Kernel BUG found', pattern => quotemeta 'BUG: failure at'};
        push @$serial_failures, {type => $type, message => 'Kernel Ooops found', pattern => quotemeta '-[ cut here ]-'};
    }

    push @$serial_failures, {type => 'soft', message => 'Low memory problem detected bsc#1166955', pattern => quotemeta 'kswapd0 Kdump'};

    # CPU soft lockup detection will lead to a message instead of a soft or hard failure
    push @$serial_failures, {type => 'info', message => 'CPU soft lockup detected', pattern => quotemeta 'soft lockup - CPU'};

    # Detect Out of Memory condition
    push @$serial_failures, {type => 'hard', message => 'Out of memory', pattern => quotemeta 'Out of memory:'} if !(is_ltp_test());

    return $serial_failures;
}

=head2 create_list_of_autoinst_failures

To add a known bug simply copy and adapt the following line:
C<push @$autoinst_failures, {type => soft/hard, message => 'Errormsg', pattern => quotemeta 'ErrorPattern' };>
type=soft will force the testmodule result to softfail
type=hard will just emit a soft fail message but the module will do a normal fail
type=info will message the user but the module will not fail

=cut

sub create_list_of_autoinst_failures {
    my $autoinst_failures = [];

    return $autoinst_failures;
}

=head2 create_list_of_journal_failures

To add a known bug simply copy and adapt the following line:
C<push @$journal_failures, {type => soft/hard, message => 'Errormsg', pattern => quotemeta 'ErrorPattern' };>
type=soft will force the testmodule result to softfail
type=hard will just emit a soft fail message but the module will do a normal fail

=cut

sub create_list_of_journal_failures {
    my $journal_failures = [];

    return $journal_failures;
}

=head2 upload_journal

Checks the journal for known patterns defined in $journal_failures
Do not touch unless you know what you're doing

=cut

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
            my $regexp = $regexp_table->{pattern};
            my $message = $regexp_table->{message};
            my $type = $regexp_table->{type};

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
