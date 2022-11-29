# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: efibootmgr openssl mokutil parted coreutils sbsigntools
# Summary: Check EFI boot in images or after OS installation
# Maintainer: Martin Loviska <mloviska@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call is_efi_boot);
use version_utils qw(is_leap is_opensuse is_sle is_jeos);
use Utils::Architectures;
use jeos qw(reboot_image set_grub_gfxmode);
use registration qw(add_suseconnect_product remove_suseconnect_product);
use main_common qw(is_updates_tests);
use constant {
    SYSFS_EFI_BITS => '/sys/firmware/efi/fw_platform_size',
    GRUB_DEFAULT => '/etc/default/grub',
    GRUB_CFG => '/boot/grub2/grub.cfg',
    SYSCONFIG_BOOTLADER => '/etc/sysconfig/bootloader',
    MOCK_CRT => '/boot/efi/EFI/mock.der'
};

my @errors;

sub get_expected_efi_settings {
    my $settings = {};
    $settings->{label} = is_opensuse() ? lc(get_var('DISTRI')) : 'sles';
    $settings->{mount} = '/boot/efi';

    if (!get_var('DISABLE_SECUREBOOT', 0)) {
        $settings->{exec} = '/EFI/' . $settings->{label} . '/shim.efi';
        $settings->{label} .= '-secureboot';
    } else {
        $settings->{exec} = '/EFI/' . $settings->{label} . '/grubx64.efi';
    }

    return $settings;
}

sub efibootmgr_current_boot {
    my $ebm_raw = script_output 'efibootmgr --verbose';
    my $h = {};

    ($h->{bootid}) = $ebm_raw =~ /^BootCurrent:\s+(\d+)/m;
    die 'Missing BootCurrent: in efibootmgr\'s output' unless $h->{bootid};

    if ($ebm_raw =~ /^(Boot$h->{bootid}\*\s+(.+)\s+(\S+\([^\)]+\)\/?)+.*|Boot$h->{bootid}\*\s+(.+))$/m) {
        $h->{label} = $2 // $4;
    }
    (exists($h->{label}) && $h->{label}) or die "Missing label in Boot$h->{bootid} entry";

    ($h->{exec}) = $ebm_raw =~ /^Boot$h->{bootid}\*.*File\(([^\)]+)\).*/m;
    defined($h->{exec}) && $h->{exec} =~ s'\\'/'g;

    return $h;
}

sub check_efi_state {
    is_efi_boot or die "Image did not boot in UEFI mode!\n";
    my $expected = shift;

    # check UEFI firmware bitness
    validate_script_output 'cat ' . SYSFS_EFI_BITS, sub { $_ == 64 };

    # check SecureBoot according to efivars
    # get data from efivars
    # {8be4df61-93ca-11d2-aa0d-00e098032b8c} {global} efi_guid_global EFI Global Variable
    # save only the first capture
    my ($efi_guid_global, undef) = script_output('efivar --list-guids') =~ /\{((\w+-){3,4}\w+)\}.*\s+efi_guid_global\s+/;
    diag "Found efi guid=$efi_guid_global";
    diag('Expected state of SecureBoot: ' . (get_var('DISABLE_SECUREBOOT', 0) ? 'Disabled' : 'Enabled'));

    if (script_run("efivar -dn $efi_guid_global-SecureBoot") == !get_var('DISABLE_SECUREBOOT', 0)) {
        push @errors, 'System\'s SecureBoot state is unexpected according to efivar';
    }

    # get current boot information from efibootmgr
    my $found = efibootmgr_current_boot;
    if (exists($expected->{exec}) && $expected->{exec}) {
        record_info "Expected", "EFI executable: $expected->{exec} ( $expected->{label} )";
        record_info "Found", "EFI executable: $found->{exec} ( $found->{label} )";
        unless (exists $found->{exec} && exists $found->{label} &&
            $found->{exec} eq $expected->{exec} && $found->{label} eq $expected->{label}) {
            push @errors, 'No efi executable found by efibootmgr or SUT booted using unexpected efi binary';
        }
    } else {
        record_info "Fallback", "EFI label: $found->{label}";
    }

    if (!get_var('DISABLE_SECUREBOOT', 0) && $found->{exec} && $expected->{exec}) {
        diag("Check presence of signature in shim");
        assert_script_run("pesign -S -i $expected->{mount}/$found->{exec}");
        #check if MokListRT is present in kernel's keyring
        if (script_output('cat /proc/keys') !~ qr/Secure\s+Boot\s+CA/) {
            if (is_aarch64) {
                record_soft_failure 'bsc#1188366 - MokListRT is not loaded into keyring on aarch64';
            } else {
                push @errors, 'No openSUSE/SUSE keys found in keyring(/proc/keys)';
            }
        }
    }
}

sub check_mok {
    my $state = !get_var('DISABLE_SECUREBOOT', 0) ? qr/^SecureBoot\senabled$/ : qr/^SecureBoot\sdisabled$/;
    # check SecureBoot according to MOK
    diag('Expected regex used to verify SecureBoot: ' . $state);
    validate_script_output 'mokutil --sb-state', $state;

    my $output = script_output('mokutil --list-new', proceed_on_failure => 1);
    if ($output eq '' || $output =~ /MokNew is empty/) {
        record_info 'MOK updates', 'No new certificates are expected to be enrolled';
    } else {
        push @errors, 'No new boot certificates are expected';
    }

    if (script_run(qq[mokutil --list-enrolled | tee /dev/$serialdev | grep -E "CN=.*SUSE"]) && !get_var('DISABLE_SECUREBOOT', 0)) {
        push @errors, 'SUSE nor openSUSE certificate has not been found by mokutil';
    }

    # In 3rd test object with SecureBoot, tests creates, imports and enrolles a mock certificate that should be removed
    unless (script_run "test -f ${\MOCK_CRT}") {
        record_info 'MOK delete', 'Removing MOCK certificate';
        assert_script_run 'mokutil --list-enrolled | grep -E "CN=MOCK"';
        if (script_output("mokutil --delete ${\MOCK_CRT} --root-pw") =~ /SKIP:\s+${\MOCK_CRT}\s+is\s+not\s+in\s+MokList/) {
            push @errors, 'CN=MOCK certificate has not been found in MokList';
        }
        assert_script_run "rm ${\MOCK_CRT}";
        assert_script_run 'mokutil --list-delete';
    }
}

sub get_esp_info {
    my $blk_dev_driver = {
        qemu => 'virtblk',
        svirt_xen => 'xvd',
        svirt_hyperv => 'scsi'
    };
    # return a the first element (drive or partition number) from parted's output
    my ($drive, $esp_part_no);
    my $vbd = $blk_dev_driver->{join('_', grep { $_ } (get_required_var('BACKEND'), get_var('VIRSH_VMM_FAMILY')))};
    foreach my $line (split(/\n/, script_output('parted --list --machine --script'))) {
        if (!defined($drive) && $line =~ /gpt/ && $line =~ /$vbd/) {
            ($drive) = split(/:/, $line, 2);
        }
        # older versions of parted used in sle12+ do not detect ESP specifically
        # it is only labelled with "boot" flag instead of "boot, esp" as in sle15+
        if (!defined($esp_part_no) && $line =~ /boot,\s?esp|boot/) {
            ($esp_part_no) = split(/:/, $line, 2);
        }
    }
    ($drive && $esp_part_no) or die "No ESP partition or GPT drive was detected from parted's output";
    my ($esp_fs, $esp_mp) = split /\s+/, script_output "df --output=fstype,target --local $drive$esp_part_no | sed -e /^Type/d";
    ($esp_fs && $esp_mp) or die "No mounted ESP partition was not found!\n";

    assert_script_run "parted --script $drive align-check optimal $esp_part_no";
    return {drive => $drive, partition => "$drive$esp_part_no", fs => $esp_fs, mount => $esp_mp};
}

sub verification {
    my ($self, $msg, $expected, $before_reboot, $after_reboot) = @_;

    $before_reboot->() if ($before_reboot && ref($before_reboot) eq 'CODE');
    $self->reboot_image($msg) if ($msg);
    check_efi_state $expected;
    $after_reboot->() if ($after_reboot && ref($after_reboot) eq 'CODE');
    check_mok;
}

sub download_file {
    my $datafile = shift;
    assert_script_run "curl " . data_url("kernel/module/$datafile") . " -o $datafile";
}

sub download_kernel_source {
    my @kv = split /\./, script_output "uname -r";
    my ($kv0, $kv1, $kv2) = ($kv[0], $kv[1], (split /-/, $kv[2])[0]);    ## keep only numerical part of the last item
    ## ex. https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-5.10.58.tar.gz
    my $url = "https://mirrors.edge.kernel.org/pub/linux/kernel/v$kv0.x/linux-$kv0.$kv1.$kv2.tar.gz";
    ## high timeout bc can take longer to download and extract kernel source
    assert_script_run "curl " . $url . "| tar xz --strip-components=1 -C /usr/src/linux", timeout => 600;
}


sub enable_verbosity {
    my $self = shift;
    assert_script_run 'mokutil --set-verbosity true';
    $self->verification('After shim-install', $self->{exp_data}, sub {
            assert_script_run('rpm -q shim');
            assert_script_run('shim-install --config-file=' . GRUB_CFG);
            assert_script_run('grub2-mkconfig -o ' . GRUB_CFG);
        }
    );
}


sub sign_kernel_module {
    my $self = shift;
    $self->verification('Import key to MOK and sign kernel module', $self->{exp_data}, sub {
            assert_script_run qq(openssl req -new -x509 -newkey rsa:2048 -sha256 -keyout key.asc -out ${\MOCK_CRT} -outform der -nodes -days 444 -addext "extendedKeyUsage=codeSigning" -subj "/CN=MOCK/");
            # compile and sign a simple kernel module
            zypper_call "in kernel-devel flex bison libopenssl-devel";
            download_kernel_source;
            assert_script_run "pushd /usr/src/linux && make olddefconfig && make scripts && popd";
            download_file 'Makefile';
            download_file 'hello.c';
            assert_script_run "make";
            # check module not signed, output must be empty
            validate_script_output "modinfo hello.ko|grep signer:", sub { !$_ }, proceed_on_failure => 1;
            assert_script_run "/usr/src/linux/scripts/sign-file sha256 key.asc ${\MOCK_CRT} hello.ko";
            # ensure module is signed now
            validate_script_output "modinfo hello.ko|grep signer:", qr/MOCK/;
            # try to insert module before enrolling the key, should give a fail message
            validate_script_output "insmod hello.ko", qr/Key was rejected by service/, proceed_on_failure => 1;
            # enroll module into UEFI
            assert_script_run "mokutil --import ${\MOCK_CRT} --root-pw";
            assert_script_run 'mokutil --list-new';
            set_var('_EXPECT_EFI_MOK_MANAGER', 1);
        },
        sub {
            # This code is executed after reboot
            # try to insert module once key is enrolled
            assert_script_run "insmod hello.ko";
            # dmesg output should contain 'Hello world.'
            validate_script_output "dmesg | tail -3", qr/Hello world./s;
        }
    );
}
sub disable_secureboot {
    my $self = shift;
    $self->verification('After grub2-install', $self->{exp_data}, sub {
            assert_script_run('sed -ie s/SECURE_BOOT=.*/SECURE_BOOT=no/ ' . SYSCONFIG_BOOTLADER);
            assert_script_run "grub2-install --efi-directory=$self->{esp_details}->{mount} --target=x86_64-efi $self->{esp_details}->{drive}";
            assert_script_run('grub2-mkconfig -o ' . GRUB_CFG);
        }
    );
}

sub restore_prev_config {
    my $self = shift;
    ## Keep previous configuration
    $self->verification('After pbl reinit', $self->{exp_data}, sub {
            my $state = !get_var('DISABLE_SECUREBOOT', 0) ? 'yes' : 'no';
            assert_script_run(q|grep -E "SECURE_BOOT=['\"]?| . $state . q|[\"']?" | . SYSCONFIG_BOOTLADER);
            assert_script_run 'update-bootloader --reinit';
        }
    );
}

sub run {
    my $self = shift;
    select_serial_terminal;
    is_efi_boot or die "Image did not boot in UEFI mode!\n";

    my $pkgs = 'efivar mokutil';
    $pkgs .= ' dosfstools' if (is_leap('<15.2') || is_sle('<15-sp2'));
    $pkgs .= ' pesign' unless get_var('DISABLE_SECUREBOOT', 0);
    zypper_call "in $pkgs";

    $self->{esp_details} = get_esp_info;

    # run fs check on ESP
    record_info "ESP", "Partition [$self->{esp_details}->{partition}], \nFilesystem [$self->{esp_details}->{fs}],\nMountPoint [$self->{esp_details}->{mount}]";
    assert_script_run "umount $self->{esp_details}->{mount}";
    assert_script_run "fsck.vfat -vV $self->{esp_details}->{partition}";
    assert_script_run "mount $self->{esp_details}->{mount}";

    # SUT can boot from removable (firstboot of HDD, ISO, USB bootable medium) or boot entry (non-removable)
    # JeOS always boots firstly from removable, but the boot record will be changed to non-removable by updates
    # Therefore the expected boot for JeOS under development and maintenance updates test slow might be different
    # Installed SUT by YaST2 boots from non-removable by default
    $self->{exp_data} = get_expected_efi_settings;
    my $booted_from_removable = is_jeos;
    if ($booted_from_removable && is_updates_tests) {
        # Updates got installed, so it might no longer be removable
        $booted_from_removable = efibootmgr_current_boot()->{label} ne $self->{exp_data}->{label};
    }

    ## default efi boot, no restart, but set gfxmode before reboot
    $self->verification(undef, $booted_from_removable ? undef : $self->{exp_data}, sub {
            set_grub_gfxmode;
            assert_script_run('grub2-script-check --verbose ' . GRUB_CFG);
        }
    );
    ## Test efi without secure boot
    if (get_var('DISABLE_SECUREBOOT')) {
        $self->disable_secureboot;
    } else {
        ## Test efi with secure boot
        # enable verbosity in shim
        $self->enable_verbosity;
        $self->sign_kernel_module if get_var('CHECK_MOK_IMPORT');
    }
    $self->restore_prev_config;

    set_var('_EXPECT_EFI_MOK_MANAGER', 0);
    # Print errors
    die join("\n", @errors) if (@errors);
}

sub post_fail_hook {
    set_var('_EXPECT_EFI_MOK_MANAGER', 0);
    select_console('log-console');

    upload_logs(GRUB_DEFAULT, log_name => 'etc_default_grub.txt');
    upload_logs(GRUB_CFG, log_name => 'grub.cfg');
    upload_logs(SYSCONFIG_BOOTLADER, log_name => 'etc_sysconfig_bootloader.txt');
    upload_logs('/etc/fstab', log_name => 'fstab.txt');
}

1;
