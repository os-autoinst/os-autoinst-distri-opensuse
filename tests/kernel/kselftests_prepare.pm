# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Prepare Kselftests (install/build and dependencies).
#
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';

use testapi;
use serial_terminal qw(select_serial_terminal);
use utils qw(write_sut_file systemctl);
use version_utils qw(is_sle has_selinux);
use Kernel::utils qw(is_debugfs_mounted enable_debugfs);
use Utils::Systemd qw(disable_and_stop_service);
use Kselftests::utils;

sub test_flags {
    return {fatal => 1};
}

sub run {
    my ($self) = @_;

    select_serial_terminal;
    record_info('KERNEL VERSION', script_output('uname -a'));
    $self->{kernel} = script_output('uname -r');

    my $collection = get_required_var('KSELFTEST_COLLECTION');

    if (livepatch_conflicts_with_kgraft($collection)) {
        record_info('SKIP', 'Skipping livepatch kselftests: KGRAFT=1 means a production '
              . 'live patch is expected to already be loaded on the SUT, which violates '
              . 'the livepatch selftest assumption of a pristine /sys/kernel/livepatch/');
        $self->result('skip');
        return;
    }

    setup_repos;
    install_dependencies($collection);

    eval {
        if (get_var('KSELFTEST_FROM_GIT', 0)) {
            install_from_git($collection);
            build($collection, '.');
        } elsif (get_var('KSELFTEST_FROM_SRC', 0)) {
            build($collection);
            install_upstream_harness();
        }
    };
    if ($@) {
        $self->{fail_reason} = $@;
        die $@;
    }

    enable_debugfs() unless is_debugfs_mounted();

    # selftests may manipulate namespaces and devices in ways that
    # trigger AVC denials on SELinux-enabled systems
    script_run('setenforce 0') if has_selinux;

    # the default firewall might interfere with many tests,
    # stop it to avoid false negative test results
    disable_and_stop_service('firewalld');

    if ($collection =~ m{^net(/|$)}) {
        if (is_sle('>=16.0')) {
            # NetworkManager interferes with tests such as busy_poll_test.sh and rtnetlink.sh, due to automatically reacting to device creation
            my $netdevsim_mask = <<'EOF';
[main]
plugins=keyfile
[keyfile]
unmanaged-devices=driver:netdevsim
EOF
            write_sut_file('/etc/NetworkManager/conf.d/99-disable-netdevsim.conf', $netdevsim_mask);
            systemctl('reload NetworkManager');
        }

        # The sit module auto-claims 2002::/16 (6to4) addresses, which are used by
        # net:tun tests as outer IPv6 tunnel addresses. This creates competing local
        # routes that prevent GENEVE-decapsulated packets from reaching the test socket
        # (observed as failures in *_gtgso send_gso_packet variants).
        script_run('rmmod sit');
    }
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    if (($self->{result} // '') eq 'fail' && defined($self->{kernel}) && ($self->{fail_reason} // '') =~ /\bmake\b.*failed/) {
        my $whitelist = get_whitelist();
        my $env = {
            product => get_var('DISTRI', '') . ':' . get_var('VERSION', ''),
            arch => get_var('ARCH', ''),
            kernel => $self->{kernel},
        };
        $whitelist->override_known_failures($self, $env, 'kselftests_prepare', '');
    }
}

1;

=head1 Description

This module prepares Linux Kernel Selftests (kselftests) for execution inside
openQA. It installs all required dependencies and the selftests themselves,
leaving the system ready for C<kselftests_run> to execute them.

Separating preparation from execution allows cloned investigation jobs to be
paused at C<kselftests_run> with the SUT already fully configured.

=head1 Configuration

=head2 KSELFTEST_COLLECTION (required)

Specifies the name of the kselftest collection to install, as reported by:

  run_kselftest.sh --list

=head2 KSELFTEST_FROM_GIT

If set, kselftests are cloned and built directly from a kernel git tree
instead of using packaged RPMs. The repository and ref are controlled by
C<KSELFTEST_GIT_TREE> and C<KSELFTEST_GIT_REF>.

=head2 KSELFTEST_GIT_TREE

URL of the kernel git repository to clone when C<KSELFTEST_FROM_GIT> is set.
Defaults to the upstream Linus tree:

  https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git

=head2 KSELFTEST_GIT_REF

Git ref (branch, tag, or commit SHA) to check out from C<KSELFTEST_GIT_TREE>
when C<KSELFTEST_FROM_GIT> is set. When unset the repository's default branch
is used.

Examples:

  KSELFTEST_GIT_REF=stable
  KSELFTEST_GIT_REF=v6.10
  KSELFTEST_GIT_REF=a3b1c2d

=head2 KSELFTEST_FROM_SRC

If set, kselftests are built from the kernel source tree provided by the
C<kernel-source> package.

=head2 KSELFTEST_BUILD_ENV

Optional string containing environment variable assignments to append to
the C<make> command when building kselftests from source (i.e. when
C<KSELFTEST_FROM_GIT> or C<KSELFTEST_FROM_SRC> is set).

Example:

  KSELFTEST_BUILD_ENV="SKIP_DOCS=1"

=head2 KSELFTEST_BUILD_JOBS

Optional number of parallel jobs passed to C<make -j> when building
kselftests from source (i.e. when C<KSELFTEST_FROM_GIT> or
C<KSELFTEST_FROM_SRC> is set). Defaults to the number of online CPUs
(C<getconf _NPROCESSORS_ONLN>). Has no effect when installing from a
pre-built RPM package.

Example:

  KSELFTEST_BUILD_JOBS=4

=cut
