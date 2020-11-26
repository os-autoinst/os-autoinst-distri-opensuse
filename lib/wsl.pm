# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
# Summary: Common WSL function
# Maintainer: qa-c  <qa-c@suse.de>

package wsl;
use Mojo::Base qw(Exporter);
use testapi;

our @EXPORT = qw(is_sut_reg);

sub is_sut_reg {
    return (get_var('SCC_REGISTER') =~ /^yast$/i);
}

1;
