# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2021 SUSE LLC
#
# Summary: Print failed test info
# Maintainer: Petr Vorel <pvorel@suse.cz>

use 5.018;
use strict;
use warnings;
use base 'opensusebasetest';
use testapi;
use version_utils qw(is_sle is_leap);

sub run {
    my ($self, $args) = @_;

    if (defined($args->{all_passed})) {
        record_info($args->{all_passed});
        return;
    }

    my $data = $args->{data};
    my $test = $data->{code};
    my $message = $data->{failure}->{message};
    my $is_v4 = get_required_var('PYNFS') eq 'nfs4.0';
    my $log = "$message\n\n$data->{failure}->{err}";
    my $softfail;

    if ($test eq 'LOCK24' && $message eq
        'OP_LOCK should return NFS4_OK, instead got NFS4ERR_BAD_SEQID') {
        $softfail = "LOCK24 failure is known, verriding to softfail: bsc#1192211";
    } elsif ($test eq 'RD5a' && is_sle && $is_v4 && $message eq
        "Reading file /b'exportdir/tree/file' should return NFS4_OK, instead got NFS4ERR_INVAL") {
        $softfail = "RD5a failure is known, verriding to softfail: bsc#1195957";
    } elsif (($test eq 'SATT15' || $test eq 'WRT18') && $is_v4 && (is_sle('<=15-sp3') or is_leap('<=15.3')) &&
        $message eq 'consecutive SETATTR(mode)\'s don\'t all change change attribute') {
        $softfail = "$test failure is known, verriding to softfail: bsc#1192210";
    }

    record_info('INFO', "name: $data->{name}\nclassname: $data->{classname}\ntime: $data->{time}\n",
        result => $softfail ? 'softfail' : 'ok');

    die 'failure does not exist' unless (exists($data->{failure}));

    if ($softfail) {
        $self->record_soft_failure_result("$softfail\n\n" . $log);
    } else {
        $self->{result} = 'fail';
        record_info('ERROR', $log, result => 'fail');
    }
}

sub test_flags {
    return {no_rollback => 1, fatal => 0};
}

1;
