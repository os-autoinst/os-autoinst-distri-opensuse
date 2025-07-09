# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Common WSL function
# Maintainer: qa-c  <qa-c@suse.de>

package wsl;
use Mojo::Base qw(Exporter);
use testapi;
use version_utils qw(is_sle);

our @EXPORT = qw(is_sut_reg is_fake_scc_url_needed wsl_choose_sles register_via_scc);

sub is_sut_reg {
    return is_sle && get_var('SCC_REGISTER') =~ /^yast$/i;
}

sub is_fake_scc_url_needed {
    return is_sut_reg && get_var('BETA', 0) && get_var('SCC_URL');
}

# WSL jeos-firstboot requires to choose from sled or sles version.
sub wsl_choose_sles {
    if (check_var('WSL_FIRSTBOOT', 'jeos')) {
        assert_screen 'wsl-sled-or-sles';
        wait_screen_change { type_string "SLES", max_interval => 125, wait_screen_change => 2 };
        send_key 'ret';
    }
}

# Register via SCC using jeos-firstboot
sub register_via_scc {
    assert_screen 'wsl-registration', 120;

    unless (is_sut_reg) {
        wait_screen_change(sub { send_key 'alt-s' }, 10);
        assert_screen 'wsl-skip-registration-warning';
        send_key 'ret';
        assert_screen 'wsl-skip-registration-checked';
        send_key 'alt-n';
        return;
    }

    my $reg_code = get_required_var('SCC_REGCODE');
    wait_screen_change(sub { send_key 'down' }, 10);
    wait_screen_change { type_string $reg_code, max_interval => 125, wait_screen_change => 2 };
    send_key 'ret';
}
1;
