# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'yama' pytest test verifying yama.ptrace_scope confinement
# Maintainer: QE Security <none@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use security::agnosticTestRunner;
use package_utils 'install_package';
use power_action_utils 'power_action';

sub run {
    my ($self) = @_;
    select_serial_terminal;
    install_package("aaa_base-yama-enable-ptrace strace", trup_continue => 1);
    assert_script_run("echo 'kernel.yama.ptrace_scope = 1' >> /etc/sysctl.conf");
    assert_script_run("sysctl --system ");
    power_action('reboot', textmode => 1);
    $self->wait_boot;
    select_serial_terminal;
    my $test = security::agnosticTestRunner->new({
            language => 'python',
            name => 'yama',
        }
    );

    $test->setup()->run_test()->parse_results()->cleanup();
}

sub test_flags {
    return {always_rollback => 1};
}

1;
