# SUSE's openQA tests
#
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm and xen support fully
# Maintainer: alice <xlai@suse.com>

package login_console;
use base 'y2_installbase';
use File::Basename;
use testapi;
use Utils::Architectures;
use Utils::Backends qw(use_ssh_serial_console is_remote_backend set_ssh_console_timeout);
use version_utils qw(is_sle is_tumbleweed is_sle_micro is_agama is_transactional);
use utils qw(is_ipxe_boot is_disk_image);
use ipmi_backend_utils;
use virt_autotest::utils qw(is_xen_host is_kvm_host check_port_state check_host_health is_monolithic_libvirtd double_check_xen_role check_kvm_modules);
use IPC::Run;

sub set_ssh_console_timeout_before_use {
    my ($sshd_config_file, $sshd_timeout) = @_;
    $sshd_config_file //= '/etc/ssh/sshd_config';
    $sshd_timeout //= 28800;

    reset_consoles;
    select_console('root-console');
    set_ssh_console_timeout($sshd_config_file, $sshd_timeout);
    reset_consoles;
    select_console 'sol', await_console => 0;
    send_key 'ret';
    check_screen([qw(linux-login virttest-displaymanager)], 60);
    save_screenshot;
    send_key 'ret';
}

sub config_ssh_client {
    my $ssh_config_file = shift;
    $ssh_config_file //= '/etc/ssh/ssh_config';
    if (script_run("ls $ssh_config_file") != 0) {
        script_run qq(echo -e "StrictHostKeyChecking no\\nUserKnownHostsFile /dev/null" > $ssh_config_file);
    }
    else {
        script_run("sed -i 's/#\\?\\([ \\t]\\+\\)\\(StrictHostKeyChecking\\)\\(.\\+\\)/\\1\\2 no/' $ssh_config_file");
        script_run("sed -i 's!#\\?\\([ \\t]\\+\\)\\(UserKnownHostsFile\\)\\(.\\+\\)!\\1\\2 /dev/null!' $ssh_config_file");
    }
    my $ssh_dir = "/root/.ssh";
    script_run("mkdir -p -m 700 $ssh_dir");
    # Replace the carrige return with string "CR" in original id_rsa key file manually
    # Note the original key file cannot include "CR"
    # Set the openqa setting '_SECRET_RSA_PUB_KEY' to be the one-line string in id_rsa
    # Finally id_rsa is restored to be the original key after following commands
    script_run("echo " . get_var('_SECRET_RSA_PRIV_KEY') . " > $ssh_dir/id_rsa");
    script_run("sed -i 's/CR/\\n/g' $ssh_dir/id_rsa");
    script_run("chmod 600 $ssh_dir/id_rsa");
    script_run("echo " . get_var('_SECRET_RSA_PUB_KEY') . " > $ssh_dir/id_rsa.pub");
    script_run("echo " . get_var('_SECRET_RSA_PUB_KEY') . " >> $ssh_dir/authorized_keys");
}

#Explanation for parameters introduced to facilitate offline host upgrade:
#OFFLINE_UPGRADE indicates whether host upgrade is offline which needs reboot
#the host and upgrade from installation media. Please refer to this document:
#https://susedoc.github.io/doc-sle/main/single-html/SLES-upgrade/#cha-upgrade-offline
#UPGRADE_AFTER_REBOOT is used to control whether reboot is followed by host
#offline upgrade procedure which needs to be treated differently compared with
#usual reboot and then login.
#REBOOT_AFTER_UPGRADE is used to control whether current reboot immediately
#follows upgrade, because certain checks are not suitable for this specific
#scenario, for example, xen kernel checking should be skipped for this reboot
#into default kvm environment after upgrading xen host.
#AFTER_UPGRADE indicates whether the whole upgrade process finishes.
sub login_to_console {
    my ($self, $timeout, $counter) = @_;
    $timeout //= 5;
    $counter //= 240;

    if (is_s390x) {
        #Switch to s390x lpar console
        reset_consoles;
        my $svirt = select_console('svirt', await_console => 0);
        return;
    }

    reset_consoles;
    reset_consoles;
    if (is_remote_backend && is_aarch64 && get_var('IPMI_HW') eq 'thunderx') {
        select_console 'sol', await_console => 1;
        send_key 'ret';
        ipmi_backend_utils::ipmitool 'chassis power reset';
    }
    else {
        select_console 'sol', await_console => 0;
    }

    if (check_var('PERF_KERNEL', '1') or check_var('CPU_BUGS', '1') or check_var('VT_PERF', '1')) {
        if (get_var("XEN") && check_var('CPU_BUGS', '1')) {
            assert_screen([qw(pxe-qa-net-mitigation qa-net-selection)], 90);
            send_key 'ret';
            assert_screen([qw(grub2 grub1)], 60);
            send_key 'up';
        }
        else {
            send_key_until_needlematch(['linux-login', 'virttest-displaymanager'], 'ret', $counter, $timeout);
            #use console based on ssh to avoid unstable ipmi
            save_screenshot;
            use_ssh_serial_console;
            return;
        }
    }

    my @bootup_needles = is_ipxe_boot ? qw(grub2) : qw(grub2 grub1 prague-pxe-menu);
    unless (get_var('UPGRADE_AFTER_REBOOT') or is_agama or is_tumbleweed or check_screen(\@bootup_needles, get_var('AUTOYAST') && !get_var("NOT_DIRECT_REBOOT_AFTER_AUTOYAST") ? 1 : 180)) {
        ipmitool("chassis power reset");
        reset_consoles;
        select_console 'sol', await_console => 0;
        check_screen(\@bootup_needles, 120);
    }

    # If a PXE menu will appear just select the default option (and save us the time)
    if (match_has_tag('prague-pxe-menu')) {
        send_key 'ret';

        check_screen([qw(grub2 grub1)], 60);
    }

    if (!get_var('UPGRADE_AFTER_REBOOT')) {
        set_var('REBOOT_AFTER_UPGRADE', '') if (get_var('REBOOT_AFTER_UPGRADE'));
        if (is_xen_host && !check_var('XEN_DEFAULT_BOOT_IS_SET', 1)) {
            #send key 'up' to stop grub timer counting down, to be more robust to select xen
            send_key 'up';
            save_screenshot;

            for (1 .. 20) {
                if ($_ == 10) {
                    reset_consoles;
                    select_console 'sol', await_console => 0;
                }
                send_key 'down';
                last if check_screen 'virttest-bootmenu-xen-kernel', 5;
            }
        }
    }
    else {
        save_screenshot;
        #offline upgrade requires upgrading offline during reboot while online doesn't
        if (get_var('OFFLINE_UPGRADE')) {
            # Wait offline upgrade starts with ssh port open. Press enter key and wait one more time to adapt to more situations
            # like grub menu with disabled timeout.
            unless (check_port_state(get_required_var('SUT_IP'), 22, 30, 10)) {
                send_key('ret') for (0 .. 2);
                die "Offline upgrade failed to start because ssh port is not open" unless (check_port_state(get_required_var('SUT_IP'), 22, 30, 10));
            }
            record_info("First stage offline upgrade starts");
            save_screenshot;
            # Wait ssh port down after first stage upgrade finishes
            my $wait_ssh_port_down = 7200;
            while ($wait_ssh_port_down >= 0) {
                last unless (check_port_state(get_required_var('SUT_IP'), 22));
                sleep 30;
                $wait_ssh_port_down -= 30;
            }
            die "First stage offline upgrade failed to finish after 2hrs" if (check_port_state(get_required_var('SUT_IP'), 22));
            record_info("First stage offline upgrade finishes");
            save_screenshot;
            # Wait system boots up for second stage upgrade
            die "Second stage offline upgrade can not start because ssh port is not open" unless (check_port_state(get_required_var('SUT_IP'), 22, 30, 10));
            record_info("System boots up for second stage offline upgrade");
            # Wait second stage upgrade finishes
            wait_still_screen(stilltime => 60, timeout => 300);
            send_key('ret') for (0 .. 2);
            assert_screen('linux-login', timeout => 60);
            record_info("Second stage offline upgrade finishes");
        }
        #setup vars
        set_var('UPGRADE_AFTER_REBOOT', '');
        set_var('REBOOT_AFTER_UPGRADE', '1');
        set_var('AFTER_UPGRADE', '1');
    }
    save_screenshot;
    send_key 'ret' unless is_tumbleweed;

    sleep 30;    # Wait for the GRUB to disappier (there's no chance for the system to boot faster
    save_screenshot;

    for (my $i = 0; $i <= 4; $i++) {
        last if (check_screen([qw(linux-login virttest-displaymanager)], 60));
        save_screenshot;
        send_key 'ret';
    }

    # Set ssh console timeout for virt tests on ipmi backend machines
    # it will make ssh serial console alive even with long time command
    # For SLE15 and TW autoyast installation, sshd configurations have been created in its autoyast profiles
    if (!is_agama and is_remote_backend and is_x86_64 and get_var('VIRT_AUTOTEST') and !(is_sle('15+') and get_var('AUTOYAST'))) {
        if (is_sle) {
            set_ssh_console_timeout_before_use;
        }
        elsif (is_sle_micro('>=6.0')) {
            set_ssh_console_timeout_before_use('/etc/ssh/sshd_config.d/sshd_config.conf', 28800);
        }
    }

    # Wait for system to be fully up and SSH port available before switching to SSH console
    # This ensures bare-metal systems have time to complete boot and network initialization
    my $sut_ip = get_required_var('SUT_IP');
    record_info("SSH port check", "Verifying SSH connectivity to $sut_ip:22 (timeout: 120s)");

    unless (check_port_state($sut_ip, 22, 120, 10)) {
        record_info("SSH port check FAILED", "System may not be fully initialized. Check network and SSH service.", result => 'fail');
        die "SSH port not available on $sut_ip:22, system may not be ready for SSH console access";
    }

    record_info("SSH port check PASSED", "System is ready, switching to SSH console");

    # use console based on ssh to avoid unstable ipmi
    use_ssh_serial_console;

    # Check 64kb page size enabled.
    if (get_var('KERNEL_64KB_PAGE_SIZE')) {
        # Verify 64kb page size enabled.
        record_info('Baremetal kernel cmdline', script_output('cat /proc/cmdline'));
        assert_script_run("dmesg | grep 'Linux version' | grep -- -64kb");
        record_info('INFO', '64kb page size enabled.');

        # Swap needs to be reinitiated
        my $swap_partition = script_output("swapon | awk '/\\/dev/{print \$1; exit}'");
        record_info('Current swap partition is ', $swap_partition);
        assert_script_run("swapoff $swap_partition");
        assert_script_run('swapon --fixpgsz');
        assert_script_run('getconf PAGESIZE');
    }

    # double-check xen role for xen host
    double_check_xen_role if (is_xen_host and !get_var('REBOOT_AFTER_UPGRADE') and !(is_sle('>=16.1') and is_transactional and is_disk_image));
    check_kvm_modules if (is_x86_64 and is_kvm_host and !get_var('REBOOT_AFTER_UPGRADE') and !(is_sle('>=16.1') and is_transactional and is_disk_image));
    check_host_health();
}

sub run {
    my $self = shift;
    $self->login_to_console;

    config_ssh_client if get_var('VIRT_AUTOTEST') and !is_agama and !get_var('AUTOYAST') and !is_s390x;
    # Make the primary interface always be the default route
    if (is_sle('16+') and get_var('SKIP_HOST_BRIDGE_SETUP', '') and get_var("SUT_PRIMARY_MAC", "") and (get_var("VIRT_NEW_GUEST_MIGRATION_SOURCE", "") or get_var("VIRT_NEW_GUEST_MIGRATION_DESTINATION", ''))) {
        my $target_mac = get_var("SUT_PRIMARY_MAC");
        my $iface = script_output("ip -br link show | grep -i '$target_mac' | awk '{print \$1}'", type_command => 1);
        $iface =~ s/^\s+|\s+$//g;
        my $gateway = script_output("ip route show default | head -n 1 | awk '{print \$3}'");
        my $ip = script_output("ip -4 addr show $iface | grep -oP 'inet \\K[\\d.]+'");
        my $net = script_output("ip route show dev $iface | grep 'proto kernel' | awk '{print \$1}'");
        script_run("ip route replace default via $gateway dev $iface metric 50");
        script_run("ip route replace $net dev $iface src $ip metric 50");
    }

    # To check if the environment are correct before tests begin
    unless (is_s390x) {
        record_info('Kernel parameters', script_output('cat /proc/cmdline'));
        record_info('NIC', script_output('ip a ; echo "" ; ip r'));
        # Upload agama script logs
        script_run("tar zcfv /tmp/host_agama_installation_script_logs.tar.gz /var/log/agama-installation/scripts/*");
        upload_logs("/tmp/host_agama_installation_script_logs.tar.gz", failok => 1);
    }
}

sub post_fail_hook {
    my ($self) = @_;
    if (check_var('PERF_KERNEL', '1') || check_var('VIRT_AUTOTEST', '1')) {
        select_console 'log-console';
        save_screenshot;
        script_run "save_y2logs /tmp/y2logs.tar.bz2";
        upload_logs "/tmp/y2logs.tar.bz2";
        save_screenshot;
        if (check_var('VIRT_AUTOTEST', '1')) {
            # show efi boot entry
            if (check_var('IPXE_UEFI', '1')) {
                record_info('UEFI entries', script_output('efibootmgr -v'));
                record_info('Boot partition contents', script_output('ls -R /boot/efi'));
            }
            if (get_var('AUTOYAST', '')) {
                script_run "tar czvf /tmp/autoinstall.tar.gz /var/adm/autoinstall";
                upload_logs "/tmp/autoinstall.tar.gz";
            }
            $self->SUPER::post_fail_hook;
        }
    }
    else {
        $self->SUPER::post_fail_hook;
    }
}

1;

