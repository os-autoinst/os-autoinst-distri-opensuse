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

    record_info('INFO', "name: $data->{name}\nclassname: $data->{classname}\ntime: $data->{time}\n");

    die 'failure does not exist' unless (exists($data->{failure}));

    $self->{result} = 'fail';
    record_info('ERROR', "$data->{failure}->{message}\n\n$data->{failure}->{err}\n");
}

sub test_flags {
    return {no_rollback => 1, fatal => 0};
}

1;
