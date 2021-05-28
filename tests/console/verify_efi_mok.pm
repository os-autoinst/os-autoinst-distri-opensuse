# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Package: efibootmgr openssl mokutil parted coreutils sbsigntools
# Summary: Check EFI boot in images or after OS installation
# Maintainer: Martin Loviska <mloviska@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use utils qw(zypper_call is_efi_boot);
use version_utils qw(is_leap is_opensuse is_sle is_jeos);
use Utils::Architectures qw(is_x86_64);
use jeos qw(reboot_image set_grub_gfxmode);
use registration qw(add_suseconnect_product remove_suseconnect_product);
use constant {
    SYSFS_EFI_BITS      => '/sys/firmware/efi/fw_platform_size',
    GRUB_DEFAULT        => '/etc/default/grub',
    GRUB_CFG            => '/boot/grub2/grub.cfg',
    SYSCONFIG_BOOTLADER => '/etc/sysconfig/bootloader',
    MOCK_CRT            => '/boot/efi/EFI/mock.der'
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
    my $h       = {};

    ($h->{bootid}) = $ebm_raw =~ /^BootCurrent:\s+(\d+)/m;
    die 'Missing BootCurrent: in efibootmgr\'s output' unless $h->{bootid};

    if ($ebm_raw =~ /^(Boot$h->{bootid}\*\s+(.+)\s+(\S+\([^\)]+\)\/?)+.*|Boot$h->{bootid}\*\s+(.+))$/m) {
        $h->{label} = $2 // $4;
    }
    (exists($h->{label}) && $h->{label}) or die "Missing label in Boot$h->{bootid} entry";

    ($h->{exec}) = $ebm_raw =~ /^Boot$h->{bootid}\*.*File\(([^\)]+)\).*/m;
    $h->{exec} =~ s'\\'/'g;

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
    my ($efi_guid_global, undef) = script_output('efivar --list-guids') =~ /\{((\w+-){4}\w+)\}.*\s+efi_guid_global\s+/;
    diag "Found efi guid=$efi_guid_global";
    diag('Expected state of SecureBoot: ' . get_var('DISABLE_SECUREBOOT', 0) ? 'Disabled' : 'Enabled');

    if (script_run("efivar -dn $efi_guid_global-SecureBoot") == !get_var('DISABLE_SECUREBOOT', 0)) {
        push @errors, 'System\'s SecureBoot state is unexpected according to efivar';
    }

    # get current boot information from efibootmgr
    my $found = efibootmgr_current_boot;
    if (exists($expected->{exec}) && $expected->{exec}) {
        record_info "Expected", "EFI executable: $expected->{exec} ( $expected->{label} )";
        record_info "Found",    "EFI executable: $found->{exec} ( $found->{label} )";
        unless (exists $found->{exec} && exists $found->{label} &&
            $found->{exec} eq $expected->{exec} && $found->{label} eq $expected->{label}) {
            push @errors, 'No efi executable found by efibootmgr or SUT booted using unexpected efi binary';
        }
    } else {
        record_info "Fallback", "EFI label: $found->{label}";
    }

    # return only if SecureBoot is off or image has booted n Fallback mode
    return if (get_var('DISABLE_SECUREBOOT', 0) || (!$found->{exec} && !$expected->{exec}));

    my $issuer_regex = qr/Secure\s+Boot\s+CA/;
    diag("Check presence of signature in shim");
    assert_script_run("pesign -S -i $expected->{mount}/$found->{exec}");
    push @errors, 'No openSUSE/SUSE keys found in keyring(/proc/keys)' if script_output('cat /proc/keys') !~ $issuer_regex;
}

sub check_mok {
    my $state = !get_var('DISABLE_SECUREBOOT', 0) ? qr/^SecureBoot\senabled$/ : qr/^SecureBoot\sdisabled$/;
    # check SecureBoot according to MOK
    diag('Expected regex used to verify SecureBoot: ' . $state);
    validate_script_output 'mokutil --sb-state', $state;

    if (script_output('mokutil --list-new', proceed_on_failure => 1) =~ /MokNew is empty/) {
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
        qemu         => 'virtblk',
        svirt_xen    => 'xvd',
        svirt_hyperv => 'scsi'
    };
    # return a the first element (drive or partition number) from parted's output
    my ($drive, $esp_part_no);
    my $vbd = $blk_dev_driver->{join('_', grep { $_ } (get_required_var('BACKEND'), get_var('VIRSH_VMM_FAMILY')))};
    foreach my $line (split(/\n/, script_output('parted --list --machine --script'))) {
        if (!defined($drive) && $line =~ /gpt/ && $line =~ /$vbd/) {
            ($drive) = split(/:/, $line, 2);
        }
        if (!defined($esp_part_no) && $line =~ /boot,\s?esp/) {
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
    my ($self, $msg, $expected, $setup) = @_;

    $setup->()                if ($setup && ref($setup) eq 'CODE');
    $self->reboot_image($msg) if ($msg);
    check_efi_state $expected;
    check_mok;
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    is_efi_boot or die "Image did not boot in UEFI mode!\n";

    my $esp_details = get_esp_info;

    # run fs check on ESP
    record_info "ESP", "Partition [$esp_details->{partition}], \nFilesystem [$esp_details->{fs}],\nMountPoint [$esp_details->{mount}]";
    assert_script_run "umount $esp_details->{mount}";
    assert_script_run "fsck.vfat -tvV $esp_details->{partition}";
    assert_script_run "mount $esp_details->{mount}";

    my $pkgs = 'efivar mokutil';
    $pkgs .= ' dosfstools' if (is_leap('<15.2') || is_sle('<15-sp2'));
    $pkgs .= ' pesign' unless get_var('DISABLE_SECUREBOOT', 0);
    zypper_call "in $pkgs";

    my $exp_data = get_expected_efi_settings;
    ## default efi boot, no restart, but set gfxmode before reboot
    $self->verification(undef, ((is_jeos) ? undef : $exp_data), sub {
            set_grub_gfxmode;
            assert_script_run('grub2-script-check --verbose ' . GRUB_CFG);
        }
    );
    ## Test efi without secure boot
    if (get_var('DISABLE_SECUREBOOT')) {
        $self->verification('After grub2-install', $exp_data, sub {
                assert_script_run('sed -ie s/SECURE_BOOT=.*/SECURE_BOOT=no/ ' . SYSCONFIG_BOOTLADER);
                assert_script_run "grub2-install --efi-directory=$esp_details->{mount} --target=x86_64-efi $esp_details->{drive}";
                assert_script_run('grub2-mkconfig -o ' . GRUB_CFG);
            }
        );
    } else {
        ## Test efi with secure boot
        # enable verbosity in shim
        assert_script_run 'mokutil --set-verbosity true';
        $self->verification('After shim-install', $exp_data, sub {
                assert_script_run('rpm -q shim');
                assert_script_run('shim-install --config-file=' . GRUB_CFG);
                assert_script_run('grub2-mkconfig -o ' . GRUB_CFG);
            }
        );
        $self->verification('Import mock key to MOK', $exp_data, sub {
                assert_script_run 'openssl req -new -x509 -newkey rsa:2048 -sha256 -keyout key.asc -out cert.pem -nodes -days 666 -subj "/CN=MOCK/"';
                assert_script_run "openssl x509 -in cert.pem -outform der -out ${\MOCK_CRT}";
                assert_script_run "mokutil --import ${\MOCK_CRT} --root-pw";
                assert_script_run 'mokutil --list-new';
            }
        ) if get_var('CHECK_MOK_IMPORT');
    }

    ## Keep previous configuration
    $self->verification('After pbl reinit', $exp_data, sub {
            my $state = !get_var('DISABLE_SECUREBOOT', 0) ? 'yes' : 'no';
            assert_script_run(q|egrep "SECURE_BOOT=['\"]?| . $state . q|[\"']?" | . SYSCONFIG_BOOTLADER);
            assert_script_run 'update-bootloader --reinit';
        }
    );

    # Print errors
    die join("\n", @errors) if (@errors);
}

sub post_fail_hook {
    select_console('root-console');

    upload_logs(GRUB_DEFAULT,        log_name => 'etc_default_grub.txt');
    upload_logs(GRUB_CFG,            log_name => 'grub.cfg');
    upload_logs(SYSCONFIG_BOOTLADER, log_name => 'etc_sysconfig_bootloader.txt');
    upload_logs('/etc/fstab',        log_name => 'fstab.txt');
}

1;
