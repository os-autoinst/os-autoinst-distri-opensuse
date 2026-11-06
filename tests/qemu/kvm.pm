# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run QEMU using KVM
# Maintainer: Dominik Heidler <dheidler@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use Utils::Architectures;
use utils;


sub run {
    select_console 'root-console';

    if (is_aarch64 && get_var('BACKEND') eq 'qemu') {
        record_info 'Skip', 'No nested virt available on aarch64 yet';
        return;
    }

    if (is_x86_64) {
        enter_cmd "qemu-system-x86_64 -nographic -enable-kvm";
        assert_screen 'qemu-no-bootable-device', 60;
    }
    elsif (is_ppc64le) {
        enter_cmd "rm -f /tmp/qemu-ppc-kvm.stderr && qemu-system-ppc64 -nographic -enable-kvm 2>/tmp/qemu-ppc-kvm.stderr";
        my $firmware_reached = check_screen ['qemu-open-firmware-ready', 'qemu-does-not-support-1tib-segments', 'qemu-ppc64-no-trans-mem'], 60;
        unless ($firmware_reached) {
            _record_ppc_kvm_diagnostics();
            die 'QEMU did not reach the expected PPC firmware screen';
        }
        if (match_has_tag 'qemu-does-not-support-1tib-segments') {
            record_soft_failure 'bsc#1124589 - qemu on ppx64le fails when called with kvm on POWER9';
            return;
        }
        elsif (match_has_tag 'qemu-ppc64-no-trans-mem') {
            # this should only happen on SLE12SP5
            record_info 'workaround', 'bsc#1118450 - qemu-system-ppc64: KVM implementation does not support Transactional Memory';
            enter_cmd "rm -f /tmp/qemu-ppc-kvm-fallback.stderr && qemu-system-ppc64 -nographic -enable-kvm -M usb=off,cap-htm=off 2>/tmp/qemu-ppc-kvm-fallback.stderr";
            unless (check_screen('qemu-open-firmware-ready', 60)) {
                _record_ppc_kvm_diagnostics();
                die 'QEMU did not reach the PPC firmware screen with cap-htm=off';
            }
        }
    }
    elsif (is_s390x) {
        # Native kvm requires SIE support (start-interpretive execution)
        die "SIE support on s390x cpu required for native kvm" if (script_run('grep sie /proc/cpuinfo') != 0);
        enter_cmd "qemu-system-s390x -nographic -enable-kvm -m 1G -kernel /boot/image -initrd /boot/initrd";
        assert_screen 'qemu-reached-target-basic-system', 60;
    }
    elsif (is_aarch64) {
        enter_cmd "qemu-system-aarch64 -M virt,usb=off,gic-version=host -cpu host -enable-kvm -nographic -pflash flash0.img -pflash flash1.img";
        assert_screen([qw(qemu-enter-boot-manager qemu-uefi-shell)], 600);
        if (match_has_tag('qemu-enter-boot-manager')) {
            send_key('e');
            assert_screen('qemu-uefi-boot-manager');
        }
    }

    # close qemu
    send_key 'ctrl-a';
    send_key 'x';
    assert_script_run '$(exit $?)';
}

sub _record_ppc_kvm_diagnostics {
    record_info('PPC system', script_output(q{
        echo '--- OS ---'; cat /etc/os-release 2>&1
        echo '--- kernel ---'; uname -a; cat /proc/cmdline
        echo '--- CPU ---'; lscpu 2>&1
        echo '--- LPAR configuration ---'; cat /proc/ppc64/lparcfg 2>&1
    }, proceed_on_failure => 1));
    record_info('PPC QEMU version', script_output('qemu-system-ppc64 --version 2>&1', proceed_on_failure => 1));
    record_info('PPC QEMU package and capabilities', script_output(q{
        rpm -qf "$(command -v qemu-system-ppc64)" 2>&1
        echo '--- machine types ---'; qemu-system-ppc64 -machine help 2>&1
        echo '--- accelerators ---'; qemu-system-ppc64 -accel help 2>&1
    }, proceed_on_failure => 1));
    record_info('PPC QEMU stderr', script_output(q{
        for logfile in /tmp/qemu-ppc-kvm.stderr /tmp/qemu-ppc-kvm-fallback.stderr; do
            if test -f "$logfile"; then echo "--- $logfile ---"; cat "$logfile"; fi
        done
    }, proceed_on_failure => 1));
    record_info('PPC KVM device', script_output(q{
        id
        ls -l /dev/kvm 2>&1; stat /dev/kvm 2>&1
        test -r /dev/kvm && echo 'KVM device readable' || echo 'KVM device not readable'
        test -w /dev/kvm && echo 'KVM device writable' || echo 'KVM device not writable'
        grep -i kvm /proc/misc /proc/devices 2>&1
    }, proceed_on_failure => 1));
    record_info('PPC KVM modules', script_output(q{
        grep -E '^(kvm|kvm_hv|kvm_pr)' /proc/modules 2>&1
        for module in kvm_hv kvm_pr; do
            if test -d "/sys/module/$module"; then echo "$module: loaded"; else echo "$module: not loaded"; fi
            modinfo -F filename "$module" 2>&1
            modinfo -p "$module" 2>&1
        done
        for parameter in /sys/module/kvm_hv/parameters/* /sys/module/kvm_pr/parameters/*; do
            if test -f "$parameter"; then echo "$parameter: $(cat "$parameter")"; fi
        done
        echo '--- KVM kernel configuration ---'
        if test -r /proc/config.gz; then zgrep '^CONFIG_KVM' /proc/config.gz; else grep '^CONFIG_KVM' "/boot/config-$(uname -r)" 2>&1; fi
    }, proceed_on_failure => 1));
    record_info('PPC KVM kernel messages', script_output(q{
        echo '--- dmesg ---'; dmesg -T 2>&1 | grep -Ei 'kvm|nested|hypervisor|papr|hcall' | tail -n 120
        echo '--- kernel journal ---'; journalctl -k -b --no-pager 2>&1 | grep -Ei 'kvm|nested|hypervisor|papr|hcall' | tail -n 120
    }, proceed_on_failure => 1));
}

1;
