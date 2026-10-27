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

subtest 'parse_zypper_table' => sub {
    my $table_auto = <<'EOF';
Loading repository data...
Reading installed packages...

S | Name   | Summary  | Type
--+--------+----------+--------
i | pkg1   | Desc 1   | package
  | pkg2   | Desc 2   | package
EOF
    is_deeply(parse_zypper_table($table_auto), [
            {s => 'i', name => 'pkg1', summary => 'Desc 1', type => 'package'},
            {s => '', name => 'pkg2', summary => 'Desc 2', type => 'package'},
    ], 'auto derive fields from header including empty cells');

    my $table_custom = <<'EOF';
Col1 | Col2
-----+-----
val1 | val2
EOF
    is_deeply(parse_zypper_table($table_custom, ['field_a', 'field_b']), [
            {field_a => 'val1', field_b => 'val2'},
    ], 'explicit fields override');

    is_deeply(parse_zypper_table('No matches found.'), [], 'no table returns empty array');
    is_deeply(parse_zypper_table(''), [], 'empty string returns empty array');
    is_deeply(parse_zypper_table(undef), [], 'undef returns empty array');

    my $header_only = <<'EOF';
S | Name | Summary | Type
--+------+---------+-----
EOF
    is_deeply(parse_zypper_table($header_only), [], 'header only returns empty array');
};

subtest 'zypper_search' => sub {
    my $mock_utils = Test::MockModule->new('utils');
    my ($mock_ret, $mock_output) = (0, '');
    $mock_utils->redefine('cmd_run', sub { return ($mock_ret, $mock_output) });

    $mock_output = <<'EOF';
S | Name           | Summary                    | Type
--+----------------+----------------------------+--------
i | kernel-default | The Standard Kernel        | package
EOF
    is_deeply(zypper_search('kernel-default'), [
            {s => 'i', status => 'i', name => 'kernel-default', summary => 'The Standard Kernel', type => 'package'},
    ], 'zypper_search parses columns dynamically and preserves status alias');

    # Exit code 104 indicates no packages found
    $mock_ret = 104;
    $mock_output = "No matching items found.\n";
    is_deeply(zypper_search('nonexistent'), [], 'exit code 104 returns empty array');
};

subtest 'zypper_repos' => sub {
    my $mock_utils = Test::MockModule->new('utils');
    my $mock_script_output = '';
    $mock_utils->redefine('script_output', sub { return $mock_script_output });

    $mock_script_output = <<'EOF';
# | Alias    | Name     | Enabled | GPG Check | Refresh
--+----------+----------+---------+-----------+--------
1 | repo-oss | Main OSS | Yes     | (r ) Yes  | Yes
EOF
    is_deeply(zypper_repos(), [
            {
                '#' => '1',
                order => '1',
                alias => 'repo-oss',
                name => 'Main OSS',
                enabled => 'Yes',
                'gpg check' => '(r ) Yes',
                gpgcheck => '(r ) Yes',
                refresh => 'Yes',
                autorefresh => 'Yes',
            },
    ], 'zypper_repos parses columns dynamically and provides legacy aliases');
};

subtest 'zypper_patches' => sub {
    my $mock_utils = Test::MockModule->new('utils');
    my $mock_script_output = '';
    $mock_utils->redefine('script_output', sub { return $mock_script_output });
    $mock_utils->redefine('is_sle', sub { 0 });

    my %patch = (
        repository => 'repo1',
        name => 'patch1',
        category => 'security',
        severity => 'critical',
        interactive => '---',
        status => 'Needed',
        summary => 'Security update 1',
    );

    $mock_script_output = <<'EOF';
Repository | Name   | Category | Severity | Interactive | Status | Since | Summary
-----------+--------+----------+----------+-------------+--------+-------+------------------
repo1      | patch1 | security | critical | ---         | Needed | 1d    | Security update 1
EOF
    is_deeply(zypper_patches(), [{%patch, since => '1d'}], 'layout with Since column');

    $mock_script_output = <<'EOF';
Repository | Name   | Category | Severity | Interactive | Status | Summary
-----------+--------+----------+----------+-------------+--------+------------------
repo1      | patch1 | security | critical | ---         | Needed | Security update 1
EOF
    is_deeply(zypper_patches(), [\%patch], 'layout without Since column');

    $mock_script_output = "No updates found.\n";
    is_deeply(zypper_patches(), [], 'no table in output');
};

done_testing();
