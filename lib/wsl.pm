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
use version_utils qw(is_sle);

our @EXPORT = qw(is_sut_reg is_fake_scc_url_needed);

sub is_sut_reg {
    return is_sle && get_var('SCC_REGISTER') =~ /^yast$/i;
}

sub is_fake_scc_url_needed {
    return is_sut_reg && get_var('BETA', 0) && get_var('SCC_URL');
}

1;
