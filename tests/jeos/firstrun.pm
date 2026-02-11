# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify provided settings for the already running JeOS system and
#          enter them going through jeos-firstboot wizard or configuring by
#          using the terminal. (E.g. timezone, locale, keymap, mounts, users,
#          passwords...)
# Maintainer: qa-c team <qa-c@suse.de>

use base "opensusebasetest";
use lockapi qw(mutex_create mutex_wait);
use testapi;
use version_utils qw(is_wsl is_jeos is_sle is_tumbleweed is_leap is_opensuse is_microos is_sle_micro
  is_leap_micro is_vmware is_bootloader_sdboot is_bootloader_grub2_bls has_selinux_by_default is_community_jeos is_sles4sap is_transactional);
use Utils::Architectures;
use Utils::Backends;
use jeos qw(expect_mount_by_uuid is_translations_preinstalled);
use utils qw(assert_screen_with_soft_timeout ensure_serialdev_permissions enter_cmd_slow);
use serial_terminal 'prepare_serial_console';
use Utils::Logging qw(record_avc_selinux_alerts);
use wsl qw(wsl_choose_sles register_via_scc wsl_firstboot_refocus);

my $user_created = 0;

sub post_fail_hook {
    script_run('timedatectl');
    script_run('locale');
    script_run('cat /etc/vconsole.conf');
    script_run('cat /etc/fstab');
    script_run('ldd --help');
}

sub verify_user_info {
    my (%args) = @_;
    my $is_root = $args{user_is_root};
    my $lang = get_var('JEOSINSTLANG', 'en_US');

    my %tz_data = ('en_US' => 'UTC', 'de_DE' => 'Europe/Berlin');
    assert_script_run("timedatectl | awk '\$1 ~ /Time/ { print \$3 }' | grep ^" . $tz_data{$lang} . "\$");

    my %locale_data = ('en_US' => 'en_US.UTF-8', 'de_DE' => 'de_DE.UTF-8');
    my $locale_lang = (is_translations_preinstalled() && !get_var("JEOSINSTLANG_FORCE_LANG_EN_US", 0)) ? $lang : 'en_US';
    assert_script_run("locale | tr -d \\'\\\" | awk -F= '\$1 ~ /LC_CTYPE/ { print \$2 }' | grep ^" . $locale_data{$locale_lang} . "\$");

    my %keymap_data = ('en_US' => 'us', 'de_DE' => 'de');
    assert_script_run("awk -F= '\$1 ~ /KEYMAP/ { print \$2 }' /etc/vconsole.conf | grep ^" . $keymap_data{$lang} . "\$");

    my %lang_data = ('en_US' => 'For bug reporting', 'de_DE' => 'Eine Anleitung zum Melden');
    # User has locale defined in firstboot, root always defaults to POSIX (i.e. English)
    my $proglang = (is_translations_preinstalled() && !get_var("JEOSINSTLANG_FORCE_LANG_EN_US", 0)) ? $lang : 'en_US';
    $proglang = $is_root ? 'en_US' : $proglang;
    assert_script_run("ldd --help | grep '^" . $lang_data{$proglang} . "'");

    return if $is_root;

    if (script_run('rpm -q system-group-wheel') == 0) {
        if (!get_var('WIZARD_SKIP_USER') && script_run('groups | grep -qw wheel') && (is_sle('16+') || is_sle_micro('6.2+'))) {
            my $username = get_username();
            die "bsc#1241215 - User $username should be added to wheel group by default";
        }
    } else {
        record_info("wheel", "system group wheel is not present in the system");
    }
}

sub verify_mounts {
    my $expected_type = {mount_type => (expect_mount_by_uuid) ? 'UUID' : 'LABEL'};

    my @findmnt_entries = grep { /\s$expected_type->{mount_type}.*\stranslated\sto\s/ }
      split(/\n/, script_output('findmnt --verbose --verify'));
    (scalar(@findmnt_entries) > 0) or die "Expected mounts by $expected_type->{mount_type} have not been found\n";

    @findmnt_entries = grep { !/^$expected_type->{mount_type}/ }
      split(/\n/, script_output('findmnt --fstab --raw --noheadings --df'));
    (scalar(@findmnt_entries) == 0) or die "Not all mounts are mounted by $expected_type->{mount_type}\nUnexpected mount(s) ( @findmnt_entries )\n";

    assert_script_run('mount -fva');
}

sub verify_hypervisor {
    my $virt = script_output('systemd-detect-virt', proceed_on_failure => 1);

    return 0 if (
        is_qemu && $virt =~ /(qemu|kvm)/ ||
        is_s390x && $virt =~ /(zvm|kvm)/ ||
        is_hyperv && $virt =~ /microsoft/ ||
        is_vmware && $virt =~ /vmware/ ||
        check_var("VIRSH_VMM_FAMILY", "xen") && $virt =~ /xen/);

    if (is_qemu && is_riscv && $virt =~ /none/) {
        record_soft_failure('boo#1218309');
        return 0;
    }

    die("Unknown hypervisor: $virt");
}

sub verify_norepos {
    my $ret = script_run "zypper lr";

    # Check ZYPPER_EXIT_NO_REPOS
    die("Image should not contain any repos after first boot") if ($ret != 6);
}

sub verify_bsc {
    if (is_qemu && is_x86_64 && script_run("rpm -q qemu-guest-agent") != 0) {
        # Included in SLE-15-SP2+, TW and Leap
        die("bsc#1207135 - Missing qemu-guest-agent from virtual images") unless is_sle('<15-SP2');
    }

    if (is_qemu && script_run("rpm -q grub2-x86_64-xen") == 0) {
        die("bsc#1166474 - kvm-and-xen image contains grub2-x86_64-xen") unless is_sle('<15-SP2');
    }

    if (is_sle('>15')) {
        my $output = script_output "chronyc sources";
        die("bsc#1156884 - chronyd is missing sources") if ($output =~ /Number of sources = 0/);
    }
}

sub verify_partition_label {
    my $label = 'gpt';

    # The RPi firmware needs MBR. s390x images also use MBR.
    # Note: JeOS-for-RaspberryPi means "kiwi-templates-Minimal" and JeOS-for-RPi means "community JeOS".
    # In sle-micro the raw aarch64 images are used for RPi, hence they have contain `dos`
    if (is_s390x || get_var('FLAVOR', '') =~ /RaspberryPi/ || check_var('FLAVOR', 'JeOS-for-RPi') || (is_sle_micro("<6.2") && is_aarch64 && get_var('FLAVOR', '') =~ /(^Base$|^Default$)/)) {
        $label = 'dos';
    }

    script_output('sfdisk -l') =~ m/Disklabel type:\s+$label/ or die "Wrong partion label found, expected '$label'";
}

sub verify_esp_size {
    my $cmd = q[for d in $(lsblk -rno NAME -dpe 11,7 ); do parted -m -s "$d" unit "kiB" print 2> /dev/null | awk -F: '/esp/ { print $4 }'; done];
    my $esp_size = script_output($cmd, proceed_on_failure => 1);

    if ((my $expected = get_var('ESP_MINPART_SIZE')) > int($esp_size)) {
        die "Detected ESP is only ${esp_size} large, expected >= ${expected}kiB";
    }
}

sub verify_selinux {
    if (has_selinux_by_default) {
        my $mode = is_sle('>=16.0') && is_sles4sap() ? 'permissive' : 'enforcing';
        validate_script_output('sestatus', sub { m/SELinux status: .*enabled/ && m/Current mode: .*$mode/ }, fail_message => "SELinux is NOT enabled and set to $mode");
    } else {
        # SELinux is not default, but might be supported
        my $selinux_supported = script_run("grep -qw selinux /sys/kernel/security/lsm") == 0;
        if ($selinux_supported) {
            # supported, so it must be disabled
            assert_script_run("which sestatus", fail_message => "SELinux is supported but 'sestatus' is not available");
            validate_script_output("sestatus", sub { m/SELinux status:.*disabled/ });
        } else {
            # otherwise, then for sure /sys/fs/selinux can't exist
            assert_script_run("! test -d /sys/fs/selinux", fail_message => "SELinux is not supported but /sys/fs/selinux exists");
        }
    }
}

sub create_user_in_terminal {
    my $username = get_username();
    if (script_run("getent passwd $username") == 0) {
        record_info('user', sprintf("%s has already been created", script_output("getent passwd $username")));
        return;
    }
    elsif ($user_created) {
        die "User $username should have been created but is missing.";
    }

    my $realname = get_realname();
    my $password = get_password();
    assert_script_run "useradd -m $username -c '$realname'";
    assert_script_run "echo $username:$password | chpasswd";
    $user_created = 1;
}

sub enter_root_passwd {
    foreach my $password_needle (qw(jeos-root-password jeos-confirm-root-password)) {
        assert_screen $password_needle;
        type_password;
        send_key 'ret';
    }
}

sub create_user_in_ui {
    assert_screen [qw(jeos-create-non-root jeos-create-non-root-with-group)];

    if (get_var('WIZARD_SKIP_USER', 0)) {
        record_info('skip user', 'skipping user creation in wizard');
        for (1 .. 2) {
            wait_screen_change(sub {
                    send_key 'tab';
            }, 10);
        }
        send_key 'ret';
        return;
    }

    my $username = get_username();
    assert_screen_change { type_string $username };
    send_key "down";
    my $realname = get_realname();
    assert_screen_change { type_string $realname };
    assert_screen_change { send_key "down" } if match_has_tag('jeos-create-non-root-with-group');
    assert_screen 'jeos-create-non-root-check';
    send_key "down";

    type_password;
    wait_screen_change(sub { send_key "down" }, 25);
    type_password;
    send_key 'ret';

    $user_created = 1;
}

sub run {
    my ($self) = @_;
    my $lang = get_var('JEOSINSTLANG', 'en_US');
    # For 'en_US' pick 'en_US', for 'de_DE' select 'de_DE'
    my %locale_key = ('en_US' => 'e', 'de_DE' => 'd');
    # For 'en_US' pick 'us', for 'de_DE' select 'de'
    my %keylayout_key = ('en_US' => 'u', 'de_DE' => 'd');
    # For 'en_US' pick 'UTC', for 'de_DE' select 'Europe/Berlin'
    my %tz_key = ('en_US' => 'u', 'de_DE' => 'e');

    # JeOS on generalhw
    mouse_hide;

    # attach serial console to active VNC on z/kvm host
    # in order to interact with the firstboot wizard
    my $con;
    my $initial_screen_timeout = 300;
    if (is_s390x && is_svirt) {
        $con = select_console('svirt', await_console => 0);
        my $name = $con->name;
        enter_cmd("virsh console --devname console0 --force $name");
        # long timeout due to missing combustion/ignition config bsc#1210429
        $initial_screen_timeout = 420 if is_sle_micro;
    }

    # https://github.com/openSUSE/jeos-firstboot/pull/82 welcome dialog is shown on all consoles
    # and configuration continues on console where *Start* has been pressed
    unless (is_sle('=12-sp5')) {
        assert_screen 'jeos-init-config-screen', $initial_screen_timeout;
        # Without this 'ret' sometimes won't get to the dialog
        wait_still_screen;
        # In WSL, the new process of installing, appears in an already maximized window,
        # but sometimes it loses focus. So I created another needle to check if
        # the window is already maximized and click somewhere else to bring it to focus.
        if (check_var('WSL_FIRSTBOOT', 'jeos')) {
            wsl_firstboot_refocus;
        }
        send_key 'ret';
    }

    # kiwi-templates-JeOS images except of 12sp5 and community jeos are build w/o translations
    # jeos-firstboot >= 0.0+git20200827.e920a15 locale warning dialog has been removed
    # system locale is present in WSL with jeos-firstboot except in WSL Tumbleweed
    if (is_translations_preinstalled()) {
        my $language_to_choose = get_var('JEOSINSTLANG_FORCE_LANG_EN_US', 0) ? 'en_US' : $lang;
        assert_screen 'jeos-locale', 300;
        send_key_until_needlematch "jeos-system-locale-$language_to_choose", $locale_key{$language_to_choose}, 51;
        send_key 'ret';
    }

    # Select keyboard layout
    assert_screen 'jeos-keylayout', 300;
    send_key_until_needlematch "jeos-keylayout-$lang", $keylayout_key{$lang}, 31;
    send_key 'ret';

    # Show license
    # EULA license applies for sle products that are in GM(C) phase
    my $license = 'jeos-license';
    if ((is_sle || is_sle_micro) && !get_var('BETA')) {
        $license = 'jeos-license-eula';
    }
    assert_screen $license;
    send_key 'ret';

    # Accept EULA if required
    if (is_sle || is_sle_micro) {
        assert_screen 'jeos-doyouaccept';
        send_key 'ret';
    }

    # Select timezone
    send_key_until_needlematch "jeos-timezone-$lang", $tz_key{$lang}, 11;
    send_key 'ret';

    # Enter password & Confirm
    enter_root_passwd;

    # In sle WSL: Choose SLES or SLED
    # And register via SCC
    if (is_sle && is_wsl) {
        wsl_choose_sles;
        register_via_scc;
    }

    # handle registration notice. Not in WSL.
    if ((is_sle || is_sle_micro) && !is_wsl) {
        assert_screen 'jeos-please-register';
        send_key 'ret';
    }

    if (is_bootloader_sdboot || is_bootloader_grub2_bls) {
        send_key_until_needlematch 'jeos-fde-option-enroll-recovery-key', 'down' unless check_screen('jeos-fde-option-enroll-recovery-key', 1);
        send_key 'ret';

        send_key_until_needlematch 'jeos-fde-option-enroll-root-pw', 'down' unless check_screen('jeos-fde-option-enroll-root-pw', 1);
        send_key 'ret';

        if (get_var('QEMUTPM')) {
            send_key_until_needlematch 'jeos-fde-option-enroll-tpm', 'down' unless check_screen('jeos-fde-option-enroll-tpm', 1);
            send_key 'ret';
        }

        # All options used up, so no need to press 'Done' explicitly anymore.

        # Continues below to verify that /etc/issue shows the recovery key
    }

    # Only execute this block on SLE Micro 6.0+ when using the encrypted image.
    if (get_var('FLAVOR') =~ m/-encrypted/i) {
        # Select FDE with pass and tpm
        assert_screen "alp-fde-pass-tpm";
        # with the latest ALP 9.2/SLEM 3.4 build, this step takes more time than usual.
        wait_screen_change(sub { send_key "ret" }, 25);
        assert_screen("alp-fde-newluks", timeout => 120);
        type_password;
        send_key "ret";
        wait_still_screen 2;
        type_password;
        send_key "ret";
        # Disk encryption is gonna take time
        assert_screen 're-encrypt-finished', 720 unless is_sle_micro('>=6.2') || is_sle('>=16');
    }

    unless (is_sle('<16') || is_sle_micro('<6.1') || is_leap('<16')) {
        if (!is_wsl) {
            assert_screen 'jeos-ssh-enroll-or-not', 120;

            if (get_var('SSH_ENROLL_PAIR')) {
                mutex_wait 'dhcp';
                sleep 30;    # make sure we have an IP
                mutex_create 'SSH_ENROLL_PAIR';
                send_key 'y';
                check_screen 'jeos-ssh-enroll-pairing', 20;
                assert_screen 'jeos-ssh-enroll-paired', 120;
                send_key 'y';
                assert_screen 'jeos-ssh-enroll-import', 120;
                send_key 'y';
                assert_screen 'jeos-ssh-enroll-imported', 120;
                send_key 'ret';
            } else {
                send_key 'n';
            }
        }
        create_user_in_ui();
    }

    # Only Default flavors come with pre-installed cockpit
    if ((is_sle_micro('>6.0') || is_leap_micro('>6.0')) && get_var('FLAVOR', '') =~ /default/i) {
        assert_screen 'jeos-totp-for-cockpit';
        # serial console is too small for generated QR to show up with additional textbox
        # another button is present in the UI in order to display the QR in a separated view
        my $tabs = is_s390x ? 3 : 2;
        for (1 .. $tabs) {
            wait_screen_change(sub {
                    send_key 'tab';
            }, 10);
        }
        send_key 'ret';
    }

    if (is_generalhw && is_aarch64 && !is_tumbleweed) {
        assert_screen 'jeos-please-configure-wifi';
        send_key 'n';
    }


    if (is_bootloader_sdboot || is_bootloader_grub2_bls) {
        # Verify that /etc/issue shows the recovery key
        wait_serial(qr/^Recovery key:\s+(([a-z]+-)+[a-z]+)/m) or die 'The encryption recovery key is missing';
    }

    # Our current Hyper-V host and it's spindles are quite slow. Especially
    # when there are more jobs running concurrently. We need to wait for
    # various disk optimizations and snapshot enablement to land.
    # Meltdown/Spectre mitigations makes this even worse.
    if (is_generalhw && !defined(get_var('GENERAL_HW_VNC_IP'))) {
        # Wait jeos-firstboot is done and clear screen, as we are already logged-in via ssh
        wait_still_screen;
        $self->clear_and_verify_console;
    }

    # For WSL we have replicated firstrun-wsl up to this point
    # Therefore we will end the test here, temporarily.
    # Open ticket to expand the test in the future.
    elsif (is_wsl) {
        assert_screen 'wsl-linux-prompt';
        enter_cmd_slow "exit\n";
        return;
    }

    else {
        assert_screen [qw(linux-login reached-power-off)], 1000;
        if (match_has_tag 'reached-power-off') {
            die "At least it reaches power off, but booting up failed, see boo#1143051. A workaround is not possible";
        }
    }

    # release console and reattach to be used again as serial output
    if (is_s390x && is_svirt) {
        # enable root ssh login, see poo#154309
        if (is_sle_micro('>=6.0') || is_sle('15-SP6+')) {
            record_info "enable root ssh login";
            enter_cmd "root";    # login to serial console at first
            wait_still_screen 1;
            enter_cmd "$testapi::password";
            wait_still_screen 1;
            enter_cmd "echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf";
            enter_cmd "systemctl restart sshd";
        }
        send_key('ctrl-^-]');
        $con->attach_to_running();
    }
    select_console('root-console', skip_set_standard_prompt => 1, skip_setterm => 1, skip_disable_key_repeat => 1);


    type_string('1234%^&*()qwerty');
    assert_screen("keymap-letter-data-$lang");
    send_key('ctrl-u');
    # Set 'us' keyboard as openQA can't operate with non-us keyboard layouts
    if ($lang ne 'en_US') {
        # With the foreign keyboard, type 'loadkeys us'
        my %loadkeys_reset = ('de_DE' => 'loadkezs us');
        enter_cmd("$loadkeys_reset{$lang}");
        wait_still_screen;
    }
    # Manually configure root-console as we skipped some parts in root-console's activation
    $testapi::distri->disable_key_repeat_if_applicable() unless current_console() =~ /ssh/;
    $testapi::distri->set_standard_prompt('root');
    assert_script_run('setterm -blank 0') unless is_s390x;

    verify_user_info(user_is_root => 1);

    # Create user account, if image doesn't already contain user
    # (which is the case for SLE images that were already prepared by openQA)
    # new jeos-firstboot supports non-root user creation
    create_user_in_terminal;

    if (check_var('FLAVOR', 'JeOS-for-RaspberryPi')) {
        assert_script_run("echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/permit-root-login.conf");
    }

    ensure_serialdev_permissions;

    prepare_serial_console;

    my $console = select_console 'user-console';
    verify_user_info;
    enter_cmd "exit";
    $console->reset();

    select_console 'root-console';
    if ($lang ne 'en_US') {
        assert_script_run("sed -ie '/KEYMAP=/s/=.*/=us/' /etc/vconsole.conf");
    }

    # openSUSE JeOS has SWAP mounted as LABEL instead of UUID until kiwi 9.19.0, so tw and Leap 15.2+ are fine
    verify_mounts unless is_aarch64;

    verify_hypervisor unless is_generalhw;
    verify_norepos unless is_opensuse;
    verify_bsc if (is_jeos && !is_transactional);
    verify_partition_label;
    verify_esp_size if (is_jeos && (is_x86_64 || is_aarch64) && !is_community_jeos && !check_var('FLAVOR', 'JeOS-for-RaspberryPi'));
    verify_selinux;
}

sub post_run_hook {
    shift->record_avc_selinux_alerts;
}

sub test_flags {
    return {fatal => 1};
}


1;
