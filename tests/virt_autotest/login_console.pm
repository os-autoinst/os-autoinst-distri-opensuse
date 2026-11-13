# SUSE's openQA tests
#
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm and xen support fully
# Maintainer: alice <xlai@suse.com>

package login_console;
use Mojo::Base 'y2_installbase';
use File::Basename;
use testapi;
use Utils::Architectures;
use Utils::Backends qw(use_ssh_serial_console is_remote_backend set_ssh_console_timeout is_pvm is_ipmi);
use version_utils qw(is_sle is_tumbleweed is_sle_micro is_agama is_transactional);
use utils qw(is_ipxe_boot is_disk_image reconnect_mgmt_console);
use ipmi_backend_utils;
use virt_autotest::utils qw(is_xen_host is_kvm_host check_port_state check_host_health is_monolithic_libvirtd double_check_xen_role check_kvm_modules check_host_version);
use IPC::Run;
use MIME::Base64 qw(decode_base64);

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

    reset_and_select_console();
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
            check_host_version if is_sle;
            return;
        }
    }

    my @bootup_needles = is_ipxe_boot ? qw(grub2) : qw(grub2 grub1 prague-pxe-menu);
    my $check_screen_timer = ((get_var('AUTOYAST') && !get_var("NOT_DIRECT_REBOOT_AFTER_AUTOYAST")) or is_disk_image) ? 1 : 180;
    unless (get_var('UPGRADE_AFTER_REBOOT') or is_agama or is_tumbleweed or check_screen(\@bootup_needles, $check_screen_timer)) {
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
        last if (check_screen([qw(linux-login virttest-displaymanager emergency-mode)], 60));
        save_screenshot;
        send_key 'ret';
    }
    # Do not keep pressing 'ret' on maintenance prompt or wait for ssh port that never opens,
    # post_fail_hook takes care of collecting logs from emergency mode
    die "Host booted into emergency mode" if (match_has_tag('emergency-mode'));

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

    # Ensure SSH port is open before switching to SSH console.
    # On slow bare-metal machines (e.g. zoe, jayne), sshd may not be ready
    # even though the login screen is already visible on SOL console.
    # Two-stage check: fast polling first, then slower retries. Max 5 min total.
    my $sut_ip = get_required_var('SUT_IP');
    unless (check_port_state($sut_ip, 22, 24, 5)    # Stage 1: every 5s  for 2 min
        || check_port_state($sut_ip, 22, 6, 30))    # Stage 2: every 30s for 3 min
    {
        die "SSH port not available on $sut_ip after 5min, system may not be ready";
    }

    # use console based on ssh to avoid unstable ipmi
    use_ssh_serial_console;

    # Make sure that the host runs the expected version and not an old system from disk
    check_host_version if is_sle;

    # Check 64kb page size enabled.
    if (get_var('KERNEL_64KB_PAGE_SIZE') || check_var('KERNEL_64KB', '1')) {
        record_info('Baremetal kernel cmdline', script_output('cat /proc/cmdline'));
        assert_script_run("dmesg | grep 'Linux version' | grep -- -64kb");
        record_info('INFO', '64kb page size enabled.');

        # Swap needs to be reinitiated
        my $swap_partition = script_output("swapon | awk '/\\/dev/{print \$1; exit}'");
        record_info('Current swap partition is ', $swap_partition);
        if ($swap_partition) {
            assert_script_run("swapoff $swap_partition");
            assert_script_run('swapon --fixpgsz');
        }
        assert_script_run('getconf PAGESIZE | grep -qx 65536');
    }

    # double-check xen role for xen host
    double_check_xen_role if (is_xen_host and !get_var('REBOOT_AFTER_UPGRADE') and !(is_sle('>=16.1') and is_transactional and is_disk_image));
    check_kvm_modules if (is_x86_64 and is_kvm_host and !get_var('REBOOT_AFTER_UPGRADE') and !(is_sle('>=16.1') and is_transactional and is_disk_image));
}

# Reset and select backend console to ensure good connectivity. User can pass in
# on argument to specify the desired number of reset before selecting console.
sub reset_and_select_console {
    my $reset_times = shift;
    $reset_times //= 2;

    reset_consoles for (0 .. $reset_times - 1);
    if (is_remote_backend && is_aarch64 && get_var('IPMI_HW') eq 'thunderx') {
        select_console 'sol', await_console => 1;
        send_key 'ret';
        ipmi_backend_utils::ipmitool 'chassis power reset';
    }
    elsif (is_pvm) {
        reconnect_mgmt_console;
    }
    else {
        select_console 'sol', await_console => 0;
    }
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

    check_host_health();
}

# Collect logs when host is in emergency/maintenance mode and ssh is unavailable.
# Log in as root on the SOL console and show diagnostics on screen so that they are
# recorded in screenshots and the video even when the worker has no route to the
# SUT at all, then print the tarball base64-wrapped on the SOL console and
# recover it into ulogs/ on the worker, which uploads it with the other logs.
# Only then try to start sshd to upload complete logs: starting it re-arms
# sulogin and can kill the emergency shell, which would lose the console
# transfer typed after it. Returns 1 if ssh is available afterwards, otherwise 0.
sub collect_emergency_mode_logs {
    my $sut_ip = get_required_var('SUT_IP');

    reset_consoles;
    select_console 'sol', await_console => 0;
    save_screenshot;
    # Check the screen before pressing 'ret': on the maintenance prompt another
    # empty 'ret' redraws the prompt, it is not a login attempt. The first
    # frame can be the wrapped one the needle misses (job 22250124), so on a
    # miss press 'ret' once to redraw the clean prompt and look again. Match
    # the return value instead of match_has_tag, which would still report the
    # tag of an earlier match when the screen did not match at all.
    my $emergency_mode = check_screen('emergency-mode', 5);
    unless ($emergency_mode) {
        send_key 'ret';
        $emergency_mode = check_screen('emergency-mode', 15);
    }
    unless ($emergency_mode) {
        # Without the matched maintenance prompt the password would be typed
        # as a username and echoed into screenshots and video
        record_info('No emergency mode match', "Port 22 is not open on $sut_ip and the emergency mode screen was not matched "
              . 'on the SOL console, no logs collected', result => 'fail');
        return 0;
    }
    record_info('Emergency mode', "Host $sut_ip is in emergency/maintenance mode", result => 'fail');

    # Log in as root on the maintenance prompt; the password is sent only once
    type_password;
    send_key 'ret';
    wait_still_screen(3);
    # The maintenance prompt stays on screen after a successful login: the
    # shell prompt below it scrolls the prompt up by one line, still inside
    # the needle margin, so a plain needle re-check would mistake the
    # successful login for a failed one and the retry would type the
    # password into the root shell. Wipe the frame with 'clear' and require
    # a fresh root shell prompt before typing anything else.
    enter_cmd('clear');
    wait_still_screen(3);
    my $login_screen = check_screen([qw(emergency-mode text-logged-in-root)], 10);
    if ($login_screen && match_has_tag('emergency-mode')) {
        record_info('Root login failed', 'Maintenance prompt still shown after entering the root password, no logs collected', result => 'fail');
        return 0;
    }
    unless ($login_screen && match_has_tag('text-logged-in-root')) {
        record_info('No root shell match', 'No root shell prompt matched on the SOL console after the maintenance login, no logs collected', result => 'fail');
        return 0;
    }

    # Show diagnostics on the SOL console; they stay available in screenshots and
    # the video even if sshd can not be started below
    enter_cmd('clear; systemctl --failed --no-pager; echo; echo "===== /proc/cmdline ====="; cat /proc/cmdline');
    wait_still_screen(3);
    save_screenshot;
    enter_cmd('clear; journalctl -b -p err --no-pager | tail -n 40');
    wait_still_screen(3);
    save_screenshot;
    # Capture 'systemctl status' for every failed unit (e.g. boot-efi.mount) together
    # with its journal. Clear the screen before each unit so that one screenshot per
    # unit shows a full status output.
    enter_cmd('for u in $(systemctl list-units --failed --no-legend --plain | awk \'{print $1}\'); do '
          . 'clear; echo "===== systemctl status $u ====="; systemctl status "$u" --no-pager; echo; '
          . 'echo "===== journalctl -u $u ====="; journalctl -b -u "$u" --no-pager | tail -n 25; echo; sleep 15; done');
    for (1 .. 12) {
        save_screenshot;
        sleep 15;
    }

    # Build the tarball once in the SOL shell, before sshd is started, so the
    # same recipe feeds both the ssh upload and the base64 fallback below.
    # /run is tmpfs and writable even if the root filesystem is mounted read-only
    my $sol_log_dir = '/run/emergency_mode_logs';
    enter_cmd("mkdir -p $sol_log_dir && journalctl -b --no-pager -o short-precise > $sol_log_dir/journal.log");
    enter_cmd("systemctl --failed --no-pager > $sol_log_dir/failed_units.log");
    enter_cmd("cat /proc/cmdline > $sol_log_dir/cmdline.log");
    enter_cmd("cp /etc/fstab $sol_log_dir/fstab");
    enter_cmd("(lsblk -f; echo; blkid; echo; findmnt) > $sol_log_dir/storage.log 2>&1");
    # rdsosreport.txt only exists in dracut's initramfs emergency shell, not in
    # systemd emergency mode after switch-root
    enter_cmd("test -f /run/initramfs/rdsosreport.txt && cp /run/initramfs/rdsosreport.txt $sol_log_dir/ "
          . "|| echo 'no rdsosreport.txt (systemd emergency mode, not dracut)'");
    enter_cmd("tar czf /run/emergency_mode_logs.tar.gz -C /run emergency_mode_logs");

    # Print the tarball base64-wrapped on the SOL console BEFORE sshd is
    # started: starting sshd re-arms sulogin and can drop the console back to
    # the maintenance prompt, so anything typed after it lands in a password
    # prompt instead of the log. With HARDWARE_CONSOLE_LOG=1 the xterm session
    # is logged to ulogs/hardware-console-log.txt on the worker; recover the
    # tarball from it and drop it into ulogs/, which the worker uploads with
    # the other logs at the end of the job. The markers must be standalone
    # lines, the typed command wraps and contains the same strings.
    enter_cmd('echo =====OPENQA-EMERGENCY-LOGS-BEGIN=====; base64 /run/emergency_mode_logs.tar.gz; echo =====OPENQA-EMERGENCY-LOGS-END=====');
    # Wait for the base64 stream to finish before the job may tear down the console
    wait_still_screen(30, 180);

    enter_cmd('systemctl start sshd.service');
    if (check_port_state($sut_ip, 22, 6, 10)) {
        # Upload the tarball built above over ssh; /run is tmpfs so it
        # survives the console switch
        reset_consoles;
        select_console 'log-console';
        upload_logs('/run/emergency_mode_logs.tar.gz', failok => 1);
        return 1;
    }

    # No ssh: recover the tarball from the base64 stream that is already in
    # ulogs/hardware-console-log.txt
    my $saved = 0;
    if (-e 'ulogs/hardware-console-log.txt') {
        for (1 .. 12) {
            last unless (open my $fh, '<', 'ulogs/hardware-console-log.txt');
            local $/;
            my $content = <$fh>;
            close $fh;
            if (defined $content && $content =~ /=====OPENQA-EMERGENCY-LOGS-BEGIN=====[^\S\n]*\r?\n(.*?)=====OPENQA-EMERGENCY-LOGS-END=====/s) {
                my $base64 = $1;
                $base64 =~ s/[^A-Za-z0-9+\/=]//g;
                mkdir 'ulogs' unless -d 'ulogs';
                if (open my $out, '>', 'ulogs/emergency_mode_logs.tar.gz') {
                    print $out decode_base64($base64);
                    close $out;
                    $saved = 1;
                }
                last;
            }
            sleep 10;
        }
    }
    record_info('Tarball over SOL', 'Port 22 is closed, /run/emergency_mode_logs.tar.gz was transferred base64-wrapped over the SOL console and '
          . ($saved ? 'saved to ulogs/emergency_mode_logs.tar.gz, which the worker uploads with the other logs'
            : 'could not be recovered from ulogs/hardware-console-log.txt; extract the base64 block between the standalone OPENQA-EMERGENCY-LOGS marker lines manually'),
        result => 'fail');
    return 0;
}

sub post_fail_hook {
    my ($self) = @_;
    my $ssh_available = 1;
    if (is_ipmi) {
        $ssh_available = check_port_state(get_required_var('SUT_IP'), 22, 3, 10);
        if (!$ssh_available) {
            # An exception from the collector (console selection or a command
            # that times out) must not skip the parent hook: catch it, record
            # it and keep going so SUPER::post_fail_hook runs in every case
            my $collected = eval { collect_emergency_mode_logs() };
            if ($@) {
                record_info('Emergency mode log collection failed', "collect_emergency_mode_logs died:\n$@", result => 'fail');
            }
            else {
                # The collector starts sshd on the SOL console when it can:
                # 1 means ssh is available again, 0 that it stays unreachable
                $ssh_available = $collected;
            }
        }
    }
    # All further log collection relies on ssh consoles, skip it if ssh can not be recovered
    if ($ssh_available && (check_var('PERF_KERNEL', '1') || check_var('VIRT_AUTOTEST', '1'))) {
        select_console 'log-console';
        # show efi boot entry
        if (check_var('IPXE_UEFI', '1') or check_var('UEFI', '1')) {
            record_info('UEFI entries', script_output('efibootmgr -v', proceed_on_failure => 1));
            record_info('Boot partition contents', script_output('ls -R /boot/efi', proceed_on_failure => 1));
        }
        # collect autoyast logs
        if (get_var('AUTOYAST', '') or get_var('AUTOYAST_PREPARE_PROFILE', '')) {
            save_screenshot;
            script_run "save_y2logs /tmp/y2logs.tar.bz2";
            upload_logs "/tmp/y2logs.tar.bz2";
            save_screenshot;
            script_run "tar czvf /tmp/autoinstall.tar.gz /var/adm/autoinstall";
            upload_logs "/tmp/autoinstall.tar.gz";
            save_screenshot;
        }
    }
    if (!$ssh_available) {
        # ssh never came back: keep the parent-hook call, but stop its
        # ssh-dependent steps from retrying the dead connection. NOLOGS is
        # the flag the parent chain checks before its ssh-based log
        # collection (get_ip_address, save_upload_y2logs, the
        # opensusebasetest export, save_system_logs, save_strace_gdb_output),
        # so propagate it just for this call and restore the previous value
        my $nologs = get_var('NOLOGS');
        set_var('NOLOGS', 1);
        # NOLOGS is not checked by every parent step: the console switch in
        # get_to_console still tries ssh and dies with 'No route to host'
        # when the network is gone, which would abort the rest of the hook.
        # Catch it, record it and keep going
        eval { $self->SUPER::post_fail_hook };
        record_info('Parent post_fail_hook incomplete', "SUPER::post_fail_hook died:\n$@", result => 'fail') if $@;
        set_var('NOLOGS', $nologs);
    }
    else {
        $self->SUPER::post_fail_hook;
    }
}

1;

