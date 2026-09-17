# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Salt master-minion integration tests (install, configure,
#          key accept, ping, cmd.run, grains, state apply, pillar, cleanup)
# Maintainer: Zoltan Balogh <zbalogh@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';
use version_utils qw(is_jeos is_opensuse is_sle is_leap is_community_jeos);
use registration 'add_suseconnect_product';
use agnosticTestRunner;

sub _register_salt_module {
    return unless is_jeos && !is_opensuse;
    my $major = get_required_var('VERSION') =~ s/([0-9]+).*/$1/r;
    if ($major == '12') {
        add_suseconnect_product('sle-module-adv-systems-management', $major);
    } elsif ($major == '15') {
        my $ver = get_required_var('VERSION') =~ s/([0-9]+)-SP([0-9]+)/$1.$2/r;
        add_suseconnect_product('sle-module-server-applications', $ver);
    }
}

sub run {
    select_serial_terminal;
    _register_salt_module();
    # Legacy salt.pm skips salt-minion install on JeOS SLE < 16
    # (pre-installed). Unconditional install is safe -- zypper
    # handles already-installed packages as a no-op.
    install_package('salt-master salt-minion', trup_continue => 1);

    my $test = agnosticTestRunner->new({
            language => 'python',
            name => 'testSalt',
            domain => 'console',
            run_timeout => 600,
        }
    );
    $test->setup()->run_test()->parse_results()->cleanup();
}

sub test_flags {
    return {no_rollback => 1};
}

1;
