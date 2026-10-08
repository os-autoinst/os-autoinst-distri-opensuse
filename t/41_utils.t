use strict;
use warnings;
use Test::More;
use Test::MockModule;
use testapi qw(set_var get_var check_var);
use utils;
use version_utils;

subtest 'need_unlock_after_bootloader' => sub {
    my $version_utils = Test::MockModule->new('utils');

    set_var('DISTRI', 'microos');
    set_var('BOOTLOADER', 'systemd-boot');
    set_var('QEMUTPM', '1');
    # set_var('VERSION', 'Tumbleweed');
    $version_utils->mock('is_boot_encrypted', sub { 0 });
    is(need_unlock_after_bootloader(), 0, 'MicroOS with sdboot and QEMUTPM returns 0');

    set_var('VERSION', 'Tumbleweed');
    set_var('DISTRI', 'opensuse');
    set_var('ENCRYPT', 0);
    set_var('QEMUTPM', 1);
    is(need_unlock_after_bootloader(), 0, 'TPM and ENCRYPT=0 with bls bootloader returns 0');

    set_var('ENCRYPT', 1);
    set_var('QEMUTPM', undef);
    set_var('BOOTLOADER', undef);

    set_var('DISTRI', 'sle');
    set_var('VERSION', '15-sp6');
    set_var('LVM', '1');
    set_var('FULL_LVM_ENCRYPT', '1');
    $version_utils->mock('is_boot_encrypted', sub { 1 });
    is(need_unlock_after_bootloader(), 0, 'Newer SLE with LVM and encrypted boot returns 0');

    set_var('VERSION', '15-sp5');
    is(need_unlock_after_bootloader(), 1, 'Older SLE needs unlocking');

    set_var('VERSION', '15-sp6');
    set_var('SYSTEM_ROLE', 'Common_Criteria');
    set_var('FULL_LVM_ENCRYPT', '1');
    set_var('ARCH', 's390x');
    is(need_unlock_after_bootloader(), 1, 'Common Criteria on s390x forces unlock (returns 1)');
};

done_testing();
