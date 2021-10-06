# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
package LTP::TestInfo;
use Mojo::Base 'OpenQA::Test::RunArgs';

our @EXPORT_OK = qw(testinfo);
use Exporter 'import';

has 'runfile';
has 'test';
has test_result_export => sub { die 'Require test_result_export hashref'; };

sub testinfo {
    __PACKAGE__->new(test_result_export => shift @_, @_);
}

1;
