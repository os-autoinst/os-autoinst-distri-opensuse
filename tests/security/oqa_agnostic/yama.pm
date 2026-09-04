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
use agnosticTestRunner;
use package_utils 'install_package';
use power_action_utils 'power_action';

sub restore_ptrace_scope {
    my ($self) = @_;
    # run() tightens kernel.yama.ptrace_scope for the whole system and persists it, which
    # would otherwise confine anything scheduled after this module
    script_run('rm -f /etc/sysctl.d/99-yama-openqa.conf');
    script_run("sysctl -w kernel.yama.ptrace_scope=$self->{orig_ptrace_scope}") if defined $self->{orig_ptrace_scope};
}

sub run {
    my ($self) = @_;
    select_serial_terminal;
    install_package("aaa_base-yama-enable-ptrace strace", trup_continue => 1);
    # remember the pre-test state so it can be put back afterwards
    $self->{orig_ptrace_scope} = script_output('sysctl -n kernel.yama.ptrace_scope 2>/dev/null || echo 0');
    # use a drop-in: /etc/sysctl.conf is not shipped on SLE 16 and later
    assert_script_run("echo 'kernel.yama.ptrace_scope = 1' > /etc/sysctl.d/99-yama-openqa.conf");
    assert_script_run("sysctl --system ");
    power_action('reboot', textmode => 1);
    $self->wait_boot;
    select_serial_terminal;
    my $test = agnosticTestRunner->new({
            language => 'python',
            name => 'yama',
            domain => 'security',
        }
    );

    $test->setup()->run_test()->parse_results()->cleanup();
}

sub post_run_hook {
    my ($self) = @_;
    $self->restore_ptrace_scope;
    $self->SUPER::post_run_hook;
}

sub post_fail_hook {
    my ($self) = @_;
    $self->restore_ptrace_scope;
    $self->SUPER::post_fail_hook;
}

1;
