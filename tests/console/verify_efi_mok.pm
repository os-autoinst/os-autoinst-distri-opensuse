# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
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
use version_utils qw(is_leap is_opensuse is_sle);
use Utils::Backends qw(is_hyperv is_svirt_except_s390x);
use jeos qw(reboot_image set_grub_gfxmode);
use constant {
    SYSFS_EFI_BITS      => '/sys/firmware/efi/fw_platform_size',
    FSTAB               => '/etc/fstab',
    GRUB_DEFAULT        => '/etc/default/grub',
    GRUB_CFG            => '/boot/grub2/grub.cfg',
    SYSCONFIG_BOOTLADER => '/etc/sysconfig/bootloader'
};

sub get_expected_efi_settings {
    my $settings      = {};
    my $efi_rec_label = (is_opensuse() ? (lc get_var('DISTRI')) : 'sles');
    my $efi_exec      = $efi_rec_label . '/grubx64.efi';

    if (!get_var('DISABLE_SECUREBOOT', 0)) {
        $efi_exec = $efi_rec_label . '/shim.efi';
        $efi_rec_label .= '-secureboot';
    }
    $settings->{exec}  = '/EFI/' . $efi_exec;
    $settings->{label} = $efi_rec_label;

    return $settings;
}
sub efibootmgr_current_boot {
    my $ebm_raw = script_output 'efibootmgr --verbose';
    my $h       = {};

    ($h->{bootid}) = $ebm_raw =~ /^BootCurrent:\s+(\d+)/m;
    die("Missing BootCurrent: in efibootmgr output") unless (defined($h->{bootid}));

    if ($ebm_raw =~ /^(Boot$h->{bootid}\*\s+(.+)\s+(\S+\([^\)]+\)\/?)+.*|Boot$h->{bootid}\*\s+(.+))$/m) {
        $h->{label} = $2 // $4;
    }
    die("Missing label in Boot$h->{bootid} entry") unless (exists($h->{label}) or defined($h->{label}));

    ($h->{exec}) = $ebm_raw =~ /^Boot$h->{bootid}\*.*File\(([^\)]+)\).*/m;
    if (defined($h->{exec})) {
        $h->{exec} =~ s'\\'/'g;
    }

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
    validate_script_output
      "od --address-radix=n --format=u1 /sys/firmware/efi/vars/SecureBoot-$efi_guid_global/data",
      sub { $_ == !get_var('DISABLE_SECUREBOOT', 0) };

    # get current boot information from efibootmgr
    my $efi = efibootmgr_current_boot;

    diag("Found:\nlabel=$efi->{label}\nexecutable=$efi->{exec}");
    diag("Expected:\nlabel=$expected->{label}\nexecutable=$expected->{exec}");

    if (exists $expected->{exec} && defined $expected->{exec}) {
        record_info "Expected", "EFI executable: $expected->{exec} ( $expected->{label} )";
        if (exists $efi->{exec} && defined $efi->{exec}) {
            ($efi->{exec} eq $expected->{exec} && $efi->{label} eq $expected->{label}) or die "System booted using unexpected efi binary\n";
        } else {
            die "No efi executable found!";
        }
        record_info "Found", "EFI executable: $efi->{exec} ( $efi->{label} )";
    } else {
        record_info "Fallback", "EFI label: $efi->{label}";
        return;
    }

    return if (get_var('DISABLE_SECUREBOOT', 0));

    my $issuer_regex = is_opensuse() ? qr/^\s+issuer:\s+\/CN=openSUSE Secure Boot CA/ :
      qr/^\s+issuer:\s+\/CN=SUSE Linux Enterprise Secure Boot CA/;
    diag("Verifying shim's certificate");
    (grep /$issuer_regex/, split /\n/, script_output "sbverify --list $expected->{mount}/$efi->{exec}") or
      die "No SUSE/openSUSE certificate has been found in sbverify's output";
    assert_script_run 'openssl x509 -in $(rpm -ql shim | grep crt) -inform DER -text -out shim.crt';
    assert_script_run "sbverify --cert shim.crt $expected->{mount}/$efi->{exec}";

    if (script_run "cat /proc/keys | tee -a /dev/$serialdev | grep asym") {
        if (is_leap('=15.1')) {
            record_soft_failure('boo#1170896 - secureboot keys not found in /proc/keys');
        } else {
            die "No asymetric keys in keyring";
        }
    }
}

sub check_mok {
    my $state = !get_var('DISABLE_SECUREBOOT', 0) ? qr/^SecureBoot\senabled$/ : qr/^SecureBoot\sdisabled$/;
    # check SecureBoot according to MOK
    diag('Expected regex used to verify SecureBoot: ' . $state);
    validate_script_output 'mokutil --sb-state', $state;

    my $new_mok_keys = script_output('mokutil --list-new', proceed_on_failure => 1);
    if ($new_mok_keys =~ /MokNew is empty/) {
        record_info 'MOK updates', 'No new certificates are expected to be enrolled';
    } elsif ($new_mok_keys =~ /^Failed.*MokNew:.*directory/) {
        record_soft_failure('bsc#1170889 -  mokutil: Failed to read MokNew');
    } else {
        die "No new boot certificates are expected";
    }

    my $rc = script_run('mokutil --list-enrolled | grep ' . (is_sle() ? 'O=SUSE' : 'O=openSUSE'));
    die "Unexpected certificate has been enrolled!\n" if ($rc && !get_var('DISABLE_SECUREBOOT', 0));

    unless (script_run 'test -f /boot/efi/EFI/mock.der') {
        assert_script_run 'mokutil --list-enrolled | grep CN=MOCK';
        assert_script_run 'mokutil --delete /boot/efi/EFI/mock.der --root-pw';
        assert_script_run 'rm /boot/efi/EFI/mock.der';
        assert_script_run 'mokutil --list-delete | grep CN=MOCK';
    }
}

sub virtualized_block_type {
    my $backend        = join('_', grep { $_ } (get_required_var('BACKEND'), get_var('VIRSH_VMM_FAMILY')));
    my $blk_dev_driver = {
        qemu         => 'virtblk',
        svirt_xen    => 'xvd',
        svirt_hyperv => 'scsi'
    };

    return $blk_dev_driver->{$backend};
}

sub get_esp_from_parted {
    my @parted_data = split /\n/, script_output 'parted --list --machine --script';
    # return a the first element (drive or partition number) from parted's output
    my $extract_from_parted = sub { return (split /:/, shift())[0] };
    # locate drive record_info
    # old dos partition table is not supported in JeOS
    my $vbt = virtualized_block_type();
    my ($drive_raw_record) = grep(/gpt/ && /$vbt/, @parted_data) or die "No gpt table found!\n";

    # find possible boot partitions in JeOS image
    my $boot_esp->{drive} = $extract_from_parted->($drive_raw_record);
    map {
        $boot_esp->{part_no}   = $extract_from_parted->($_);
        $boot_esp->{partition} = $boot_esp->{drive} . $boot_esp->{part_no};
    } grep(/boot,\s?esp/, @parted_data);

    assert_script_run "parted --script $boot_esp->{drive} align-check optimal $boot_esp->{part_no}";

    return $boot_esp;
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

    my $esp_details = get_esp_from_parted;
    die "Image did not boot in UEFI mode!\n"
      unless ($esp_details && is_efi_boot && get_required_var('UEFI'));

    my $pkgs = 'efivar mokutil';
    $pkgs .= ' dosfstools' if (is_leap('<15.2') || is_sle('<15-sp2'));
    unless (get_var('DISABLE_SECUREBOOT', 0)) {
        # temporary hack for sle, due to missing sbsigntools package
        if (is_sle) {
            (my $version = get_var('VERSION')) =~ s/-/_/g;
            $version =~ s/SP3/SP2/g;
            zypper_call("ar -p 101 --refresh --no-gpgcheck http://download.opensuse.org/repositories/Base:/System/SLE_$version/ sb_signtools");
        }
        $pkgs .= ' sbsigntools';
    }
    zypper_call "in $pkgs";

    # store ESP's file system and mount point
    my ($efi_p_fs, $efi_p_mp) = split(/\s+/,
        script_output 'df --output=fstype,target,source --local | grep ' . $esp_details->{partition});
    ($efi_p_fs && $efi_p_mp && $esp_details->{partition}) or die "No mounted ESP partition was not found!\n";

    record_info "esp [$esp_details->{partition}]", "\nFilesystem [$efi_p_fs],\nMountPoint [$efi_p_mp]";

    # run fs check on ESP
    assert_script_run "umount $efi_p_mp";
    assert_script_run "fsck.vfat -tvV $esp_details->{partition}";
    assert_script_run "mount $efi_p_mp";

    my $exp_data = get_expected_efi_settings;
    $exp_data->{mount} = $efi_p_mp;
    ## default efi boot, no restart, but set gfxmode before reboot
    $self->verification(undef, undef, sub {
            set_grub_gfxmode;
            assert_script_run('grub2-script-check --verbose ' . GRUB_CFG);
        }
    );
    ## Test efi without secure boot
    if (get_var('DISABLE_SECUREBOOT')) {
        $self->verification('After grub2-install', $exp_data, sub {
                assert_script_run('sed -ie s/SECURE_BOOT=.*/SECURE_BOOT=no/ ' . SYSCONFIG_BOOTLADER);
                assert_script_run "grub2-install --efi-directory=$efi_p_mp --target=x86_64-efi $esp_details->{drive}";
                assert_script_run('grub2-mkconfig -o ' . GRUB_CFG);
            }
        );
    } else {
        ## Test efi with secure boot
        # enable verbosity in shim
        assert_script_run 'mokutil --set-verbosity true';
        $self->verification('After shim-install', $exp_data, sub {
                assert_script_run('shim-install --config-file=' . GRUB_CFG);
                assert_script_run('grub2-mkconfig -o ' . GRUB_CFG);
            }
        );
        $self->verification('Import mock key to MOK', $exp_data, sub {
                assert_script_run 'openssl req -new -x509 -newkey rsa:2048 -sha256 -keyout key.asc -out cert.pem -nodes -days 666 -subj "/CN=MOCK/"';
                assert_script_run 'openssl x509 -in cert.pem -outform der -out /boot/efi/EFI/mock.der';
                assert_script_run 'mokutil --import /boot/efi/EFI/mock.der --root-pw';
                assert_script_run 'mokutil --list-new';
            }
        );
    }

    ## Keep previous configuration
    $self->verification('After pbl reinit', $exp_data, sub {
            my $state = !get_var('DISABLE_SECUREBOOT', 0) ? 'yes' : 'no';
            assert_script_run(q|egrep "SECURE_BOOT=['\"]?| . $state . q|[\"']?" | . SYSCONFIG_BOOTLADER);
            assert_script_run 'update-bootloader --reinit';
        }
    );

    unless (get_var('DISABLE_SECUREBOOT', 0)) {
        zypper_call 'rm sbsigntools';
        zypper_call 'rr sb_signtools' if is_sle;
    }
}

sub post_fail_hook {
    select_console('root-console');

    upload_logs(GRUB_DEFAULT,        log_name => 'etc_default_grub.txt');
    upload_logs(GRUB_CFG,            log_name => 'grub.cfg');
    upload_logs(SYSCONFIG_BOOTLADER, log_name => 'etc_sysconfig_bootloader.txt');
    upload_logs(FSTAB,               log_name => 'fstab.txt');
}

1;
