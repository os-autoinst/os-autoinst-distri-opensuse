=head1 bootloader_pvm

Library for spvm and pvm_hmc backend to boot and install SLES

=cut
# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

package bootloader_pvm;

use base Exporter;
use Exporter;

use strict;
use warnings;

use testapi;
use bootloader_setup;
use registration 'registration_bootloader_params';
use utils qw(get_netboot_mirror type_string_slow enter_cmd_slow);
use version_utils qw(is_agama is_upgrade);
use Utils::Backends;
use YuiRestClient;
use ntlm_auth;

our @EXPORT = qw(
  boot_pvm
);

=head2 get_into_net_boot

 get_into_net_boot();

Get into SMS menu for booting from net.

=cut

sub get_into_net_boot {
    assert_screen 'pvm-bootmenu';

    # 5.   Select Boot Options
    enter_cmd "5";
    assert_screen 'pvm-bootmenu-boot-order';

    # 1.   Select Install/Boot Device
    enter_cmd "1";
    assert_screen 'pvm-bootmenu-boot-device-type';

    # 4.   Network
    enter_cmd "4";
    assert_screen 'pvm-bootmenu-boot-network-service';

    # 1.   BOOTP
    enter_cmd "1";
    assert_screen 'pvm-bootmenu-boot-select-device';

    # primary disk
    enter_cmd "1";
    assert_screen 'pvm-bootmenu-boot-mode';

    # 2.   Normal Mode Boot
    enter_cmd "2";
    assert_screen 'pvm-bootmenu-boot-exit';

    enter_cmd "1";
    # download file from tftp server takes sometimes longer, so test could die before matching above needles
    assert_screen ["pvm-grub", "novalink-failed-first-boot"], 90;
}

=head2 reset_lpar_netboot

 reset_lpar_netboot();

Reset LPAR manually and attempt a second network boot when the first boot attempt failed in cases when the LPAR
was reconfigured during the boot process or when it fails to load the linux kernel or initrd.

=cut

sub reset_lpar_netboot {
    # the grub on powerVM has a rather strange feature that it will boot
    # into the firmware if the lpar was reconfigured in between and the
    # first menu entry was used to enter the command line. So we need to
    # reset the LPAR manually, another issue is unable to load initrd or linux kernel,
    # so in both cases we need to reset LPAR netboot
    if (match_has_tag('novalink-failed-first-boot')) {
        if (check_screen('novalink-first-boot-encrypted-passwd', 5)) {
            type_string("$testapi::password");
            send_key 'ret';
            assert_screen 'pvm-grub';
        }
        else {
            enter_cmd "set-default ibm,fw-nbr-reboots";
            enter_cmd "reset-all";
            assert_screen 'pvm-firmware-prompt';
            send_key '1';
            get_into_net_boot;
        }
    }
}

=head2 enter_netboot_parameters

 enter_netboot_parameters();

Type kernel and ramdisk parameters in grub command line.

=cut

sub enter_netboot_parameters {
    # try 3 times but wait a long time in between - if we're too eager
    # we end with ccc in the prompt
    send_key_until_needlematch('pvm-grub-command-line', 'c', 4, 5);

    # clear the prompt (and create an error) in case the above went wrong
    if (check_screen 'ccc-stays-at-grub-prompt', 10) {
        wait_still_screen 20;
        send_key 'ret';
        enter_cmd_slow 'clear';
    }

    assert_screen "pvm-grub-command-line-fresh-prompt", no_wait => 1;
    my $repo = get_required_var('REPO_0');
    my $mirror = get_netboot_mirror;
    my $mntpoint = "mnt/openqa/repo/$repo/boot/ppc64le";
    if (my $ppc64le_grub_http = get_var('PPC64LE_GRUB_HTTP')) {
        # Enable grub http protocol to load file from OSD: (http,10.145.10.207)/assets/repo/$repo/boot/ppc64le
        $mntpoint = "$ppc64le_grub_http/assets/repo/$repo/boot/ppc64le";
        record_info("Updated boot path for PPC64LE_GRUB_HTTP defined", $mntpoint);
    }
    my $ntlm_p = get_var('NTLM_AUTH_INSTALL') ? $ntlm_auth::ntlm_proxy : '';
    if (is_agama) {
        type_string_slow "linux $mntpoint/linux root=live:http://" . get_var('OPENQA_HOSTNAME') . "/assets/iso/" . get_var('ISO') . " live.password=$testapi::password console=hvc0";
        # inst.auto and inst.install_url are defined in below function
        specific_bootmenu_params;
        type_string_slow " " . get_var('EXTRABOOTPARAMS') if (get_var('EXTRABOOTPARAMS'));
    }
    else {
        type_string_slow "linux $mntpoint/linux vga=normal $ntlm_p install=$mirror ";
    }
    # Skipping this setup due to it triggers general code for openSUSE that breaks powerVM scenario
    unless (is_agama) {
        bootmenu_default_params;
        bootmenu_network_source;
        specific_bootmenu_params;
        type_string_slow remote_install_bootmenu_params;
    }

    registration_bootloader_params(utils::VERY_SLOW_TYPING_SPEED) unless get_var('NTLM_AUTH_INSTALL');
    type_string_slow " fips=1" if (get_var('FIPS_INSTALLATION'));
    type_string_slow " UPGRADE=1" if (get_var('UPGRADE'));

    send_key 'ret';
    assert_screen "pvm-grub-command-line-fresh-prompt", 180, no_wait => 1;    # kernel is downloaded while waiting
    enter_cmd_slow "initrd $mntpoint/initrd";
}

=head2 prepare_pvm_installation

 prepare_pvm_installation();

Handle the boot and installation preparation process of PVM LPARs after the hypervisor specific actions to power them on is done

=cut

sub prepare_pvm_installation {
    my ($boot_attempt) = @_;
    $boot_attempt //= 1;
    reset_lpar_netboot;
    enter_netboot_parameters;
    enter_cmd "boot";
    save_screenshot;

    # pvm has sometimes extrem performance issue, increase timeout for booting up after enter_netboot_parameters
    assert_screen(["pvm-grub-menu", "novalink-successful-first-boot"], 300);
    if (match_has_tag "pvm-grub-menu") {
        # During boot pvm-grub menu was seen again
        # Will try to setup linux and initrd again up to 3 times
        $boot_attempt++;
        die "Boot process restarted too many times" if ($boot_attempt > 3);
        return (bootloader_pvm::prepare_pvm_installation $boot_attempt);
    }

    if (is_agama) {
        record_info("Installing", "Please check the expected product is being installed");
        assert_screen('agama-installer-live-root', 400);
    }
    else {
        assert_screen("run-yast-ssh", 300);
    }

    # For Agama unattended tests, disks will be formatted by default
    if (!is_upgrade && !get_var('KEEP_DISKS') && !get_var('INST_AUTO')) {
        prepare_disks;
    }

    return if is_agama;
    # Switch to installation console (ssh or vnc)
    select_console('installation');
    # We need to start installer only if it's pure ssh installation
    # If libyui REST API is used, we set it up in installation/setup_libyui
    if (get_var('VIDEOMODE', '') =~ /ssh-x|text/ && !get_var('YUI_REST_API')) {
        # We need to set env variables when start installer in ssh
        enter_cmd("yast.ssh");
    }

    wait_still_screen;
}

=head2 boot_pvm

 boot_pvm();

Decide whether job is booting a pvm_hmc backend system or a spvm via Novalink one and call the appropriate booting function.

=cut

sub boot_pvm {
    if (is_spvm) {
        boot_spvm();
    } elsif (is_pvm_hmc) {
        boot_hmc_pvm();
    }
}

=head2 check_lpar_is_down

 check_lpar_is_down($hmc_machine_name, $lpar_id);

Check if an LPAR identified by C<$lpar_id> in the Power machine C<$hmc_machine_name> is down, by querying with the C<lssyscfg> command.
Command will check 24 times in a loop while waiting 5 seconds between each run, and exit as soon as the LPAR is down. Check is performed
by a needle match looking for the B<LPAR IS DOWN> text which is printed by the check script on success.

=cut

sub check_lpar_is_down {
    my ($hmc_machine_name, $lpar_id) = @_;
    enter_cmd("for i in {0..24}; do lssyscfg -m $hmc_machine_name -r lpar --filter \"\"lpar_ids=$lpar_id\"\" -F state | grep -q 'Not Activated' && echo 'LPAR IS DOWN' && break || echo 'Waiting for lpar $lpar_id to shutdown' && sleep 5 ; done ");
    assert_screen 'lpar-is-down', 120;
}

=head2 boot_hmc_pvm

 boot_hmc_pvm();

Boot a system connected via the hmc_pvm backend. This function will connect to the HMC command line,
issue the commands necessary to start a given LPAR (from the setting B<LPAR_ID>), by first making sure
the LPAR is down, before booting it into the System Management Services menu, and then opening a virtual
terminal to the LPAR console to navigate the SMS to either boot the LPAR from network (for installations)
or from the local disk.

=cut

sub boot_hmc_pvm {
    my $hmc_machine_name = get_required_var('HMC_MACHINE_NAME');
    my $lpar_id = get_required_var('LPAR_ID');
    my $hmc = select_console 'powerhmc-ssh';

    # print setup information
    record_info('HMC hostname', get_var('HMC_HOSTNAME'));
    record_info('HMC machine', "$hmc_machine_name");
    record_info('LPAR id', "$lpar_id");
    record_info('SUT ip', get_var('SUT_IP'));

    # Print the machine details before anything else, Firmware name might be useful when reporting bugs
    record_info("HMC machine details", "See the next screen to get details on $hmc_machine_name");
    enter_cmd "lslic -m $hmc_machine_name -t sys | sed 's/,/\\n/g'";

    # Fail the job when a lpar is not available
    die 'The managed system is not available' if check_screen('lpar_manage_status_unavailable', 3);

    # detach possibly attached terminals - might be left over
    enter_cmd "rmvterm -m $hmc_machine_name --id $lpar_id && echo 'DONE'";
    assert_screen 'pvm-vterm-closed';

    # power off the machine if it's still running - and don't give it a 2nd chance
    # sometimes lpar shutdown takes long time if the lpar was running already, we need to check it's state
    # and wait until it's finished
    enter_cmd("chsysstate -r lpar -m $hmc_machine_name -o shutdown --immed --id $lpar_id ");
    check_lpar_is_down($hmc_machine_name, $lpar_id);

    # Restore LPAR's NVRAM defaults if SET_NVRAM_DEFAULTS setting is present
    if (get_var('SET_NVRAM_DEFAULTS')) {
        # Boot into open firmware (of) first to issue a SET_NVRAM_DEFAULTS command
        enter_cmd("chsysstate -r lpar -m $hmc_machine_name -o on -b of --id $lpar_id ");
        enter_cmd("mkvterm -m $hmc_machine_name --id $lpar_id");
        assert_screen 'openfirmware-prompt', 60;
        enter_cmd('SET_NVRAM_DEFAULTS');
        assert_screen 'openfirmware-prompt';
        # Exit from LPAR's console, shutdown LPAR and continue as usual
        enter_cmd('~~.');
        assert_screen 'terminate-openfirmware-session';
        send_key 'y';
        assert_screen 'powerhmc-ssh', 60;
        enter_cmd("chsysstate -r lpar -m $hmc_machine_name -o shutdown --immed --id $lpar_id ");
        check_lpar_is_down($hmc_machine_name, $lpar_id);
    }

    # proceed with normal boot if is system already installed, use sms boot for installation
    my $bootmode = get_var('BOOT_HDD_IMAGE') ? "norm" : "sms";
    enter_cmd("chsysstate -r lpar -m $hmc_machine_name -o on -b ${bootmode} --id $lpar_id ");
    enter_cmd("for ((i=0\; i<12\; i++)); do lssyscfg -m $hmc_machine_name -r lpar --filter \"\"lpar_ids=$lpar_id\"\" -F state | grep -q -e 'Running' -e 'Firmware' && echo 'LPAR IS RUNNING' && break || echo 'Waiting for lpar $lpar_id to start up' && sleep 5 ; done ");
    assert_screen 'lpar-is-running', 60;

    # don't wait for it, otherwise we miss the menu
    enter_cmd "mkvterm -m $hmc_machine_name --id $lpar_id";
    # skip further preperations if system is already installed
    # PowerVM, send "up" key to refresh the serial terminal in case
    # it is already entered into grub2 menu
    if (get_var('BOOT_HDD_IMAGE')) {
        send_key('up');
        return;
    }
    get_into_net_boot;
    prepare_pvm_installation;
}

=head2 boot_spvm

 boot_spvm();

Boot from spvm backend via novalink and switch to installation console (ssh or vnc).

=cut

sub boot_spvm {
    my $lpar_id = get_required_var('NOVALINK_LPAR_ID');
    my $novalink = select_console 'novalink-ssh';

    # print setup information
    record_info('NOVALINK hostname', get_var('NOVALINK_HOSTNAME'));
    record_info('LPAR id', "$lpar_id");
    record_info('SUT ip', get_var('SUT_IP'));

    # detach possibly attached terminals - might be left over
    enter_cmd "rmvterm --id $lpar_id && echo 'DONE'";
    assert_screen 'pvm-vterm-closed';

    # power off the machine if it's still running - and don't give it a 2nd chance
    enter_cmd " pvmctl lpar power-off -i id=$lpar_id --hard";
    assert_screen [qw(pvm-poweroff-successful pvm-poweroff-not-running)], 180;

    # make sure that the default boot mode is 'Normal' and not 'System_Management_Services'
    # see https://progress.opensuse.org/issues/39785#note-14
    enter_cmd " pvmctl lpar update -i id=$lpar_id --set-field LogicalPartition.bootmode=Normal && echo 'BOOTMODE_SET_TO_NORMAL'";
    assert_screen 'pvm-bootmode-set-normal';

    # proceed with normal boot if is system already installed, use sms boot for installation
    my $bootmode = get_var('BOOT_HDD_IMAGE') ? "norm" : "sms";
    enter_cmd " pvmctl lpar power-on -i id=$lpar_id --bootmode ${bootmode}";
    assert_screen "pvm-poweron-successful";

    # don't wait for it, otherwise we miss the menu
    enter_cmd " mkvterm --id $lpar_id";
    # skip further preperations if system is already installed
    return if get_var('BOOT_HDD_IMAGE');
    get_into_net_boot;
    prepare_pvm_installation;
}

1;
