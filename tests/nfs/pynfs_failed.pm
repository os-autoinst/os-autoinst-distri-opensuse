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
use Data::Dumper;

sub run {
    my ($self, $args) = @_;
    my $data = $args->{data};
    my $msg;

    record_info('INFO', "name: $data->{name}\nclassname: $data->{classname}\ntime: $data->{time}\n");

    die 'failure does not exist' unless (exists($data->{failure}));

    $msg = "$data->{failure}->{message}\n\n$data->{failure}->{err}";

    if ($data->{code} eq 'LOCK24' && $data->{failure}->{message} eq
        'OP_LOCK should return NFS4_OK, instead got NFS4ERR_BAD_SEQID') {
        $self->record_soft_failure_result("LOCK24 failure is known, verriding to softfail: bsc#1192211\n\n" . $msg);
    } else {
        $self->{result} = 'fail';
        record_info('ERROR', $msg);
    }
}

sub test_flags {
    return {no_rollback => 1, fatal => 0};
}

1;
