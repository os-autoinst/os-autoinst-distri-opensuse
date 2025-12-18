# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: bpf
# Summary: Compile and load a BPF sample program from Linux mainline
# Maintainer: kernel-qa@suse.de

use Mojo::Base qw(opensusebasetest);
use testapi;
use utils;
use version_utils qw(is_sle);
use registration qw(add_suseconnect_product get_addon_fullname get_available_modules);
use serial_terminal qw(select_serial_terminal);

sub run {
    my ($self) = @_;

    select_serial_terminal;
    record_info('KERNEL VERSION', script_output('uname -a'));

    if (is_sle) {
        my $modules = get_available_modules();

        unless ($modules->{PackageHub}) {
            record_soft_failure("poo#194023 PackageHub not available - skipping BPF test");
            return;
        }

        add_suseconnect_product(get_addon_fullname('phub'));    # For clang
    }


    zypper_call("in clang bpftool libbpf-devel");

    # Build the BPF program
    assert_script_run('curl -sO ' . data_url('kernel/trace_output.bpf.c'));
    assert_script_run('bpftool btf dump file /sys/kernel/btf/vmlinux format c > vmlinux.h');
    assert_script_run('clang -g -O2 -target bpf -c trace_output.bpf.c');

    # Build the userspace test runner
    assert_script_run('curl -sO ' . data_url('kernel/trace_output_user.c'));
    assert_script_run('clang -lbpf -o trace_output trace_output_user.c');

    record_info('BPF Sample', script_output('./trace_output'));
}

1;
