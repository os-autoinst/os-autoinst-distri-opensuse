use strict;
use warnings;
use Test::More;
use Test::MockModule;
use Test::Exception;
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

subtest 'wait_for_port' => sub {
    my $utils = Test::MockModule->new('utils');
    my $target_process = "";
    my $port = "";

    $utils->mock('script_retry', sub {
            my ($cmd, %args) = @_;
            my $ecode = $args{expect} // 0;
            diag "port=$port, process=$target_process, cmd=$cmd\n";
            die("either port='$port' or process='$target_process' found") unless $cmd =~ /$port.*$target_process/;
            $ecode;
    });

    $utils->mock(record_info => sub { 0 });
    $utils->mock(script_output => sub { 0 });

    throws_ok { wait_for_port("80"); } qr/port/, "Dies if port doesn't start with :";
    throws_ok { wait_for_port(":http"); } qr/digits/, "Dies if port isn't numeric";
    throws_ok { wait_for_port(":80", process => ""); } qr/process/, "Dies if process is empty";

    $target_process = "apache";
    $port = ":80";
    throws_ok { wait_for_port($port, process => "nginx"); } qr/^either.*$port.*$target_process/, "Dies if it can't find process";

    $target_process = "java";
    $port = ":8080";
    is(wait_for_port(":8080", process => "$target_process", expect => 100), 100, "Process running on port is found with expected exit code");

};

done_testing();
