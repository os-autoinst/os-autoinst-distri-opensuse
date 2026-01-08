# SUSE's openQA tests
#
# Copyright 2017-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Collect logs from the installation system just before we try to
#   reboot into the installed system
# - If BACKEND is s390x or S390_DISK is not ZFCP, run "lsreipl | grep $dasd_path"
# to check IPL device
# - If BACKEND is ipmi or spvm, set serial console type depending, HYPERVISOR TYPE (xen,
# kvm) or ARCH (aarch64)
# - Otherwise
#   - Get ip for network interface
#   - Get /etc/resolv.conf contents
#   - Save screenshot
# - Upload yast2 installation network logs
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';
use testapi;
use Utils::Architectures;
use lockapi;
use utils;
use Utils::Backends;
use version_utils 'is_sle';
use ipmi_backend_utils;

sub run {
    my ($self) = @_;

    my $dasd_path = get_var('DASD_PATH', '0.0.0150');
    select_console 'install-shell';

    # on a CC enabled system, root ssh login is disabled by default, but we need it enabled
    if (check_var('SYSTEM_ROLE', 'Common_Criteria') && is_sle && is_s390x) {
        my $stor_inst = "/var/log/YaST2/storage-inst/*committed.yml";
        my $is_encrypted = check_var('ENCRYPT', '1') || check_var('FULL_LVM_ENCRYPT', '1');
        my $root_hd = script_output("cat $stor_inst | grep -B4 'mount_point: \"/\"' | grep name | awk -F \\\" '{print \$2}'");
        if ($is_encrypted) {
            $root_hd = "/dev/mapper/" . script_output("dmsetup ls | grep root | awk '{print \$1}'");
        }

        assert_script_run("mount $root_hd /mnt");
        assert_script_run("sed -i -e 's/PermitRootLogin no/PermitRootLogin yes/g' /mnt/etc/ssh/sshd_config");
        assert_script_run("sed -i -e 's/PermitRootLogin prohibit-password/PermitRootLogin yes/g' /mnt/etc/ssh/sshd_config.d/51-permit-root-login.conf") if is_sle('>=15-SP6');
        assert_script_run('umount /mnt');
    }

    # In FIPS + disk encrypted, if the system has a separate boot partition
    # it is required to add it to the kernel parameters, or booting the
    # system will likely fail (bsc#1198190)
    if (get_var('FIPS_INSTALLATION') && get_var('ENCRYPT') && get_var('UNENCRYPTED_BOOT')) {
        my $stor_inst = "/var/log/YaST2/storage-inst/*committed.yml";
        my $boot_hd = script_output("cat $stor_inst | grep -B4 'mount_point: \"/boot\"' | grep name | awk -F \\\" '{print \$2}'");
        assert_script_run("mount $boot_hd /mnt");
        assert_script_run("sed -i -e \"s#fips=1#boot=$boot_hd fips=1#g\" /mnt/grub2/grub.cfg");
        assert_script_run('umount /mnt');
    }

    # check for right boot-device on s390x (zVM, DASD ONLY)
    if (is_backend_s390x && !check_var('S390_DISK', 'ZFCP')) {
        if (script_run("lsreipl | grep $dasd_path")) {
            die "IPL device was not set correctly";
        }
    }
    # while technically SUT has a different network than the BMC
    # we require ssh installation anyway
    if (get_var('BACKEND', '') =~ /ipmi|spvm/) {
        use_ssh_serial_console;
        # set serial console for xen and kvm of SLE hosts
        # for openSUSE TW, it is set in other place where after kvm/xen patterns are installed
        if (is_sle) {
            set_grub_on_vh('/mnt', '', 'xen') if (get_var('XEN') || check_var('HOST_HYPERVISOR', 'xen'));
            set_grub_on_vh('/mnt', '', 'kvm') if (check_var('HOST_HYPERVISOR', 'kvm') || check_var('SYSTEM_ROLE', 'kvm'));
            adjust_for_ipmi_xen('/mnt') if (get_var('REGRESSION') && (get_var('XEN') || check_var('HOST_HYPERVISOR', 'xen')));
            set_pxe_efiboot('/mnt') if (is_aarch64 && !(get_var("VIRT_AUTOTEST")));
        }
    }
    else {
        # avoid known issue in FIPS mode: bsc#985969
        $self->get_ip_address();
    }

    # We don't change network setup here, so should work
    # We don't parse logs unless it's detect_yast2_failures scenario
    $self->save_upload_y2logs(no_ntwrk_recovery => 1, skip_logs_investigation => !get_var('ASSERT_Y2LOGS'));
    select_console 'installation' unless get_var('REMOTE_CONTROLLER');
}

sub test_flags {
    return {fatal => 0};
}

1;
