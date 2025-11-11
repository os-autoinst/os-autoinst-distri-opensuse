use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;

use testapi qw(check_var get_var set_var);

subtest 'check_version' => sub {
    # compare versions if possible
    ok version_utils::check_version($_, '15.5'), "check $_, 15.5" for qw(>15.0 <15.10);
    ok !version_utils::check_version($_, '15.5'), "check $_, 15.5" for qw(=15.50 >=15.10);

    # compare strings if not
    ok version_utils::check_version($_, 'klm'), "check $_, klm" for qw(abc+ 1+ =KLM);

    # die if regex does not match
    for (qw(1.3+ 11-sp1+)) {
        dies_ok { version_utils::check_version($_, '12-sp3', qr/^\d{2}/) } "check $_, 12-sp3, ^\\d{2}";
    }

    # die if compare symbols are wrong
    for (qw(=1.3+ >1.3+ <>1.3 > 12 abc)) {
        dies_ok { version_utils::check_version($_, '12-sp3') } "check $_, 12-sp3";
    }

    ok version_utils::check_version($_, '10.5.0-Maria'), "check $_, 15.5" for qw(>10.4.4 10.4+ >=10.4-Maria >10.3.0-MySQL);
    ok !version_utils::check_version($_, '10.5.1'), "check $_, 10.5.1" for qw(=10.4.9 <10.5.0);
    ok version_utils::check_version('>=10.4', '10.10'), "check that poo#120918 doesn't happen";
    ok version_utils::check_version('>=10.4', '10.10-mariadb'), "check that poo#120918 doesn't happen";
};

subtest 'is_microos' => sub {
    use version_utils 'is_microos';

    set_var('DISTRI', 'microos');

    ok is_microos;

    set_var('DISTRI', undef);

    ok !is_microos;
};

subtest 'is_leap' => sub {
    use version_utils 'is_leap';

    set_var('DISTRI', 'opensuse');
    ok !is_leap, "check !is_leap";

    set_var('VERSION', '42.3');
    ok is_leap, "check is_leap";
    ok is_leap($_), "check $_" for qw(=42.3 <=15.0 >42.1 >=42.3 12+);
    ok !is_leap($_), "check $_" for qw(=15.0 >42.3 <42.3 <13.0 15+);
    dies_ok { is_leap $_ } "check $_" for (qw(42.1:S:A+ =42.3:S:A 12 15- =12+ >1 <15+));

    set_var('VERSION', '42.3:S:A');
    ok is_leap($_), "check $_" for qw(=42.3 <=15.0 <15);
};

subtest 'is_sle' => sub {
    use version_utils 'is_sle';

    set_var('DISTRI', 'opensuse');
    ok !is_sle, "check !is_sle";

    set_var('DISTRI', 'sle');
    ok is_sle, "check is_sle";

    set_var('VERSION', '12');
    ok is_sle, "check is_sle";
    ok is_sle($_), "check $_" for qw(=12 >=12 <=12 12+ <12-sp1 <=15-sp2 <15 11+ >11 >=11 11-sp1+);
    ok !is_sle($_), "check $_" for qw(>12 <12 >12-sp1 15-sp1+ >=15 <=11 <11-sp2);
    dies_ok { is_sle $_ } "check $_" for (qw(12 15- =12+ >1 1-sp1+ <15+ 15-sp1));

    set_var('VERSION', '12-SP2');
    ok is_sle($_), "check $_" for qw(=12-sp2 =12-sP2 <=15 >11-sp3 <12-sp3 >12-sp1 <12-SP3 >12-SP1);

    set_var('VERSION', '16.0');
    ok is_sle($_), "check $_" for qw(=16 =16.0 <16.9 <=16.0 >=16.0 >15-SP2 15-SP7+);
    ok !is_sle($_), "check $_" for qw(>16.1 <15-sp9 <=15 >16 =16.9);
    dies_ok { is_sle $_ } "check $_" for (qw(12 15- =12+ <15+ 16.0 >15_sp2 =XY));
};

subtest 'package_version_cmp' => sub {
    use version_utils 'package_version_cmp';

    ok(package_version_cmp('1.2.3-4.5', '1.2.3-4.5') == 0, '1.2.3-4.5 == 1.2.3-4.5');
    ok(package_version_cmp('1.2.3-4.5.0', '1.2.3-4.5') == 0, '1.2.3-4.5.0 == 1.2.3-4.5');
    ok(package_version_cmp('1.2.3-4.5', '1.2.3-4.5.0') == 0, '1.2.3-4.5 == 1.2.3-4.5.0');
    ok(package_version_cmp('1.2.3-4.5.1', '1.2.3-4.5') > 0, '1.2.3-4.5.1 > 1.2.3-4.5');
    ok(package_version_cmp('1.2.3-4.5', '1.2.3-4.5.1') < 0, '1.2.3-4.5 < 1.2.3-4.5.1');
    ok(package_version_cmp('1.2.3-4.6', '1.2.3-4.5') > 0, '1.2.3-4.6 > 1.2.3-4.5');
    ok(package_version_cmp('1.2.3-4.5', '1.2.3-4.6') < 0, '1.2.3-4.5 < 1.2.3-4.6');
    ok(package_version_cmp('1.2.3-5.1', '1.2.3-4.5') > 0, '1.2.3-5.1 > 1.2.3-4.5');
    ok(package_version_cmp('1.2.3-4.5', '1.2.3-5.1') < 0, '1.2.3-4.5 < 1.2.3-5.1');

    ok(package_version_cmp('1.2.0-4.5', '1.2-4.5') == 0, '1.2.0-4.5 == 1.2-4.5');
    ok(package_version_cmp('1.2-4.5', '1.2.0-4.5') == 0, '1.2-4.5 == 1.2.0-4.5');
    ok(package_version_cmp('1.2.3.1-4.5', '1.2.3-4.5') > 0, '1.2.3.1-4.5 > 1.2.3-4.5');
    ok(package_version_cmp('1.2.3-4.5', '1.2.3.1-4.5') < 0, '1.2.3-4.5 < 1.2.3.1-4.5');
    ok(package_version_cmp('1.2.4-4.5', '1.2.3-4.5') > 0, '1.2.4-4.5 > 1.2.3-4.5');
    ok(package_version_cmp('1.2.3-4.5', '1.2.4-4.5') < 0, '1.2.3-4.5 < 1.2.4-4.5');
    ok(package_version_cmp('1.2.3.4-4', '1.2.3-4.5') > 0, '1.2.3-4.5 > 1.2.3-4.5');
    ok(package_version_cmp('1.2.3-4.5', '1.2.3.4-4') < 0, '1.2.3-4.5 < 1.2.3-4.5');

    ok(package_version_cmp('1.2.3-4.5a', '1.2.3-4.5a') == 0, '1.2.3-4.5a == 1.2.3-4.5a');
    ok(package_version_cmp('1.2.3-4.5a', '1.2.3-4.5b') < 0, '1.2.3-4.5a < 1.2.3-4.5b');
    ok(package_version_cmp('1.2.3-4.5b', '1.2.3-4.5a') > 0, '1.2.3-4.5b > 1.2.3-4.5a');
    ok(package_version_cmp('1.2.3a-4.5', '1.2.3a-4.5') == 0, '1.2.3a-4.5 == 1.2.3-4.5');
    ok(package_version_cmp('1.2.3a-4.5', '1.2.3b-4.5') < 0, '1.2.3a-4.5 < 1.2.3-4.5');
    ok(package_version_cmp('1.2.3b-4.5', '1.2.3a-4.5') > 0, '1.2.3a-4.5 > 1.2.3-4.5');

    ok(package_version_cmp('5.3.18-198.1.g6b7890d', '5.3.18-200.1.g3e09edd') < 0,
        '5.3.18-198.1.g6b7890d < 5.3.18-200.1.g3e09edd ');
    ok(package_version_cmp('5.3.18-200.1.g3e09edd ', '5.3.18-198.1.g6b7890d') > 0,
        '5.3.18-200.1.g3e09edd > 5.3.18-198.1.g6b7890d');

    ok(package_version_cmp('1.2.10+20250410', '1.2.9+20250110') > 0, '1.2.10+20250410 > 1.2.9+20250110');
    ok(package_version_cmp('1.2.9+20250110', '1.2.10+20250410') < 0, '1.2.9+20250110 < 1.2.10+20250410');
    ok(package_version_cmp('1.2.10+20250410', '1.2.9') > 0, '1.2.10+20250410 > 1.2.9');
    ok(package_version_cmp('1.2.9', '1.2.10+20250410') < 0, '1.2.9 < 1.2.10+20250410');
};

subtest 'has_selinux_by_default' => sub {
    use version_utils 'has_selinux_by_default';

    # Test Leap (SELinux not enabled by default)
    set_var('DISTRI', 'opensuse');
    set_var('VERSION', '42.3');
    ok !has_selinux_by_default, "check !has_selinux_by_default for Leap";

    # Test MicroOS (SELinux enabled by default)
    set_var('DISTRI', 'microos');
    set_var('VERSION', '0');
    ok has_selinux_by_default, "check has_selinux_by_default for MicroOS";

    # Test SLE Micro invalid version (SELinux not enabled by default)
    set_var('DISTRI', 'sle-micro');
    set_var('VERSION', '0');
    ok !has_selinux_by_default, "check !has_selinux_by_default for invalid sle-micro";

    # Test SLE Micro 5.3 (SELinux not enabled by default)
    set_var('VERSION', '5.3');
    ok !has_selinux_by_default, "check !has_selinux_by_default for sle-micro 5.3";

    # Test SLE Micro 5.4 (SELinux enabled by default)
    set_var('VERSION', '5.4');
    ok has_selinux_by_default, "check has_selinux_by_default for sle-micro 5.4";

    # Test Tumbleweed (SELinux enabled by default)
    set_var('DISTRI', 'opensuse');
    set_var('VERSION', 'Tumbleweed');
    ok has_selinux_by_default, "check has_selinux_by_default for Tumbleweed";
};

subtest 'has_selinux' => sub {
    use version_utils 'has_selinux';

    # Test SLE Micro 5.4 (enabled by default)
    set_var('DISTRI', 'sle-micro');
    set_var('VERSION', '5.4');
    ok has_selinux, "check has_selinux with default settings (sle-micro 5.4)";

    # Test SLE Micro 5.3 (not enabled by default)
    set_var('VERSION', '5.3');
    ok !has_selinux, "check !has_selinux with default settings (sle-micro 5.3)";

    # Test Tumbleweed (default enabled)
    set_var('DISTRI', 'opensuse');
    set_var('VERSION', 'Tumbleweed');
    ok has_selinux, "check has_selinux for Tumbleweed without SELINUX=1 environment";
    set_var('SELINUX', '1');
    ok has_selinux, "check has_selinux for Tumbleweed with SELINUX=1";
    set_var('SELINUX', '0');
    ok !has_selinux, "check !has_selinux for Tumbleweed with SELINUX=0";
};

subtest 'bootloader_tests' => sub {
    use version_utils qw(get_default_bootloader get_bootloader);

    set_var('DISTRI', 'opensuse');
    set_var('FLAVOR', 'Server-DVD');
    set_var('VERSION', 'Tumbleweed');
    set_var('UEFI', '0');
    ok get_default_bootloader eq 'grub2', "Tumbleweed no UEFI is grub2";

    set_var('UEFI', '1');
    ok get_default_bootloader eq 'grub2-bls', "Tumbleweed on UEFI is grub2-bls";

    set_var('VERSION', 'Slowroll');
    ok get_default_bootloader eq 'grub2', "Slowroll on UEFI is grub2";

    set_var('VERSION', 'Staging:F');
    ok get_default_bootloader eq 'grub2-bls', "Tumbleweed/Staging:F on UEFI is grub2-bls";

    set_var('DISTRI', 'sle-micro');
    set_var('VERSION', '5.5');
    set_var('FLAVOR', 'Default-Updates');
    ok get_default_bootloader eq 'grub2', "SLE Micro 5.5 is grub2";

    set_var('DISTRI', 'microos');
    set_var('VERSION', 'Tumbleweed');
    set_var('FLAVOR', 'MicroOS-Image-ContainerHost');
    ok get_default_bootloader eq 'grub2', "Container host image is grub2";

    set_var('FLAVOR', 'JeOS-for-OpenStack-Cloud');
    ok get_default_bootloader eq 'grub2', "JeOS-for-OpenStack-Cloud image is grub2";

    set_var('FLAVOR', 'MicroOS-Image');
    ok get_default_bootloader eq 'grub2', "MicroOS-Image image is grub2";

    set_var('FLAVOR', 'JeOS-for-RISCV');
    ok get_default_bootloader eq 'grub2', "JeOS-for-RISCV image is grub2";

    set_var('DISTRI', 'opensuse');
    set_var('FLAVOR', 'Server-DVD');
    set_var('UPGRADE', 1);
    ok get_default_bootloader eq 'grub2', "Upgrading Tumbleweed on UEFI is grub2";
    set_var('UPGRADE', undef);

    set_var('UEFI', '0');
    ok get_default_bootloader eq 'grub2', "Tumbleweed non UEFI is grub2";

    set_var('DISTRI', 'microos');
    ok get_default_bootloader eq 'grub2', "Microos non UEFI is grub2";

    set_var('UEFI', '1');
    ok get_default_bootloader eq 'systemd-boot', "Microos on UEFI is systemd-boot";

    set_var('UPGRADE', 1);
    ok get_default_bootloader eq 'grub2', "Old Microos UEFI is grub2";
    set_var('UPGRADE', 0);

    set_var('WSL_VERSION', '10');
    ok get_bootloader eq 'wsl', "WSL uses a custom bootloader";
    set_var('WSL_VERSION', undef);

    set_var('BOOTLOADER', 'does-not-exist');
    dies_ok { get_default_bootloader } "Bootloader variable set, non existant bootloader, causes failure";

    set_var('BOOTLOADER', 'grub2');
    ok get_default_bootloader eq 'grub2', "Forcing bootloader works";
};

done_testing;
