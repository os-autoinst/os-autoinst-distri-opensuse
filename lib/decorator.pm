=head1 decorator.pm

decorator module for libyui service

=cut

# SUSE's openQA tests
#
# Copyright 2022-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: decorator for libyui test.
# Maintainer: GAO WEI <wegao@suse.com>

package decorator;

use Exporter 'import';
use testapi;
use utils;
use strict;
use warnings;
use Sub::Util 'subname';
use experimental 'signatures';

our @EXPORT = qw(
  debug
  wrap
);

sub wrap {
    no strict;
    no warnings 'redefine';
    my ($func, $code) = @_;
    *{subname($func)} = $code->($func);
}

sub debug {
    my ($func) = @_;
    return sub (@args) {
        #record_info("decorator:before");
        save_screenshot;
        $func->(@args);
        #record_info("decorator:after");
        save_screenshot;
    }
}

1;
