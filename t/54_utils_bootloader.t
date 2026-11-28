# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Unit tests for Utils:Bootloader
# Maintainer: QE Kernel team <kernel-qa@suse.de>

use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::MockModule;

use Utils::Bootloader;
use ipmi_backend_utils;
use File::Temp qw(tempdir);
use File::Path qw(make_path);

my $mocked_arch = 'x86_64';
my $mocked_script_output = '';

my $mock_bootloader = Test::MockModule->new('Utils::Bootloader');
$mock_bootloader->redefine(
    get_var => sub {
        my ($var) = @_;
        return $mocked_arch if $var eq 'ARCH';
        return undef;
    },
    record_info => sub { 1 },
    script_output => sub { return $mocked_script_output },
    ensure_serialdev_permissions => sub { 1 },
);

$INC{'bootloader_setup.pm'} = 1;
*bootloader_setup::GRUB_CFG_FILE = sub { 't/data/mock_grub.cfg' };

subtest 'Test _get_command_line_size for all architectures' => sub {
    my %expected_sizes = (
        s390x => 4096,
        aarch64 => 2048,
        ppc64le => 2048,
        riscv64 => 2048,
        x86_64 => 2048,
        i586 => 2048,
    );

    for my $arch (sort keys %expected_sizes) {
        $mocked_arch = $arch;
        is(Utils::Bootloader::_get_command_line_size(), $expected_sizes{$arch},
            "Architecture $arch returns correct size $expected_sizes{$arch}");
    }

    $mocked_arch = 'sparc64';
    throws_ok { Utils::Bootloader::_get_command_line_size() }
    qr/unsupported.*$mocked_arch/,
      'Dies correctly when an unsupported architecture is provided';

    $mocked_arch = undef;
    throws_ok { Utils::Bootloader::_get_command_line_size() }
    qr/unsupported.*undef/,
      'Dies correctly when ARCH is undefined';
};


subtest 'Test check_kernel_arg_len limits' => sub {
    $mocked_arch = 'x86_64';

    $mocked_script_output = "/boot/vmlinuz-6.5 root=/dev/sda1 ro quiet\n";

    lives_ok { check_kernel_arg_len() }
    'check_kernel_arg_len lives when string length is well below the limit';

    $mocked_script_output = ("A" x 2048) . "\n";

    throws_ok { check_kernel_arg_len() }
    qr/fail: Kernel.*COMMAND_LINE_SIZE/,
      'check_kernel_arg_len dies when the string length exceeds the limit';
};


# ipmi_backend_utils: the commands add_kernel_options and set_grub_terminal_and_timeout run,
# for a boot loader chosen per host. With $run_file_edits set, the commands that edit files run
# for real (on files under a temporary root_dir) in bash, where "ssh root@host CMD" runs CMD the
# way the remote shell would; the boot loader tools that change the system (sdbootutil,
# update-bootloader, grub2-mkconfig) are only recorded.
my (@ipmi_cmds, %sdboot_on);
our $run_file_edits;
my $mock_ipmi = Test::MockModule->new('ipmi_backend_utils');
$mock_ipmi->redefine(
    is_systemd_boot => sub { my %a = @_; return $sdboot_on{$a{dst_machine} // 'localhost'} ? 1 : 0 },
    find_esp_mount_point => sub { return '/boot' },
    assert_script_run => sub {
        my ($cmd) = @_;
        push @ipmi_cmds, $cmd;
        system('bash', '-c', 'ssh() { shift; bash -c "$1"; }; ' . $cmd) == 0 or die "command failed: $cmd"
          if $run_file_edits && $cmd !~ /\b(sdbootutil|update-bootloader|grub2-mkconfig)\b/;
        return 1;
    },
    script_output => sub { push @ipmi_cmds, $_[0]; return '' },
    record_info => sub { 1 },
    save_screenshot => sub { 1 },
);

sub read_file { my ($f) = @_; open(my $fh, '<', $f) or die "$f: $!"; local $/; return <$fh> }
sub write_file { my ($f, $text) = @_; open(my $fh, '>', $f) or die "$f: $!"; print $fh $text; close $fh }
sub grub_touched { return grep { m{boot/grub2/grub\.cfg|etc/default/grub|grub2-mkconfig} } @ipmi_cmds }

subtest 'add_kernel_options on systemd-boot edits /etc/kernel/cmdline and refreshes the entries' => sub {
    %sdboot_on = (localhost => 1);
    for my $grub_to_change (1, 2) {
        @ipmi_cmds = ();
        add_kernel_options(kernel_opts => 'console=ttyS0,115200 mitigations=auto', grub_to_change => $grub_to_change);
        my @edits = grep { m{ /etc/kernel/cmdline$} && !/^cat / } @ipmi_cmds;
        is(scalar @edits, 2, "grub_to_change=$grub_to_change: one edit of /etc/kernel/cmdline per kernel option");
        ok((grep { /console=ttyS0,115200/ } @edits) && (grep { /mitigations=auto/ } @edits), "grub_to_change=$grub_to_change: each option is added");
        is($ipmi_cmds[-1], 'sdbootutil update-all-entries', "grub_to_change=$grub_to_change: boot entries are regenerated last");
        ok(!grub_touched(), "grub_to_change=$grub_to_change: no GRUB file is touched");
    }

    @ipmi_cmds = ();
    add_kernel_options(kernel_opts => 'quiet', grub_to_change => 3);
    is_deeply(\@ipmi_cmds, [], 'grub_to_change=3 (default grub only) changes nothing on systemd-boot');
};

subtest 'add_kernel_options on a remote systemd-boot host' => sub {
    %sdboot_on = ('sut.example.com' => 1);    # the worker itself boots with GRUB
    @ipmi_cmds = ();
    add_kernel_options(dst_machine => 'sut.example.com', kernel_opts => 'quiet');
    ok(@ipmi_cmds, 'commands are run');
    is(scalar(grep { !/^ssh root\@sut\.example\.com / } @ipmi_cmds), 0, 'every command runs over ssh on the remote host');
    ok((grep { m{ /etc/kernel/cmdline"$} } @ipmi_cmds), '/etc/kernel/cmdline is edited on the remote host');
    ok((grep { /sdbootutil update-all-entries/ } @ipmi_cmds), 'boot entries are regenerated on the remote host');
    ok(!grub_touched(), 'no GRUB file is touched on the remote systemd-boot host');
};

subtest 'add_kernel_options on GRUB is unchanged' => sub {
    %sdboot_on = ();
    @ipmi_cmds = ();
    add_kernel_options(kernel_opts => 'quiet');
    ok((grep { m{^sed .* /boot/grub2/grub\.cfg$} } @ipmi_cmds), 'grub.cfg is edited');
    ok((grep { m{^sed .* /etc/default/grub$} } @ipmi_cmds), 'default grub is edited');
    ok(!(grep { m{kernel/cmdline|sdbootutil} } @ipmi_cmds), 'nothing systemd-boot specific is run');
};

for my $dst ('localhost', 'sut.example.com') {
    subtest "the /etc/kernel/cmdline edit leaves each option exactly once ($dst)" => sub {
        my $root = tempdir(CLEANUP => 1);
        make_path("$root/etc/kernel");
        write_file("$root/etc/kernel/cmdline", "root=UUID=1234 console=ttyS0,115200 quiet\n");
        %sdboot_on = ($dst => 1);
        local $run_file_edits = 1;
        my $ok = eval { add_kernel_options(dst_machine => $dst, root_dir => $root, kernel_opts => 'console=ttyS0,115200 mitigations=auto'); 1 };
        ok($ok, 'no command fails') or diag($@);
        my $cmdline = read_file("$root/etc/kernel/cmdline");
        my @console = $cmdline =~ /(console=ttyS0,115200)/g;
        is(scalar @console, 1, 'an option already present is not duplicated');
        like($cmdline, qr/\bmitigations=auto\b/, 'a new option is added');
        like($cmdline, qr/\broot=UUID=1234\b.*\bquiet\b/, 'the other options are kept');
        is(scalar(split /\n/, $cmdline), 1, 'the kernel command line stays on one line');
    };
}

subtest 'set_grub_terminal_and_timeout on systemd-boot edits loader.conf' => sub {
    %sdboot_on = (localhost => 1);
    for my $grub_to_change (1, 2) {
        @ipmi_cmds = ();
        set_grub_terminal_and_timeout(timeout => 45, grub_to_change => $grub_to_change);
        ok((grep { m{/+boot/loader/loader\.conf} && /console-mode keep/ && /timeout 45/ } @ipmi_cmds),
            "grub_to_change=$grub_to_change: console-mode and timeout are set in <ESP>/loader/loader.conf");
        is($ipmi_cmds[-1], 'update-bootloader --refresh && sdbootutil set-timeout 45', "grub_to_change=$grub_to_change: the boot loader is refreshed and the timeout set");
        ok(!grub_touched(), "grub_to_change=$grub_to_change: no GRUB file is touched");
    }

    @ipmi_cmds = ();
    set_grub_terminal_and_timeout(grub_to_change => 3);
    is_deeply(\@ipmi_cmds, [], 'grub_to_change=3 (default grub only) changes nothing on systemd-boot');
};

subtest 'set_grub_terminal_and_timeout on a remote systemd-boot host' => sub {
    %sdboot_on = ('sut.example.com' => 1);    # the worker itself boots with GRUB
    @ipmi_cmds = ();
    set_grub_terminal_and_timeout(dst_machine => 'sut.example.com', timeout => 45);
    is(scalar(grep { !/^ssh root\@sut\.example\.com / } @ipmi_cmds), 0, 'every command runs over ssh on the remote host');
    ok((grep { m{/+boot/loader/loader\.conf} && /console-mode keep/ && /timeout 45/ } @ipmi_cmds), 'loader.conf is edited on the remote host');
    ok((grep { /sdbootutil set-timeout 45/ } @ipmi_cmds), 'the timeout is set on the remote host');
    ok(!grub_touched(), 'no GRUB file is touched on the remote systemd-boot host');
};

subtest 'set_grub_terminal_and_timeout on GRUB is unchanged' => sub {
    %sdboot_on = ();
    @ipmi_cmds = ();
    set_grub_terminal_and_timeout(timeout => 45);
    ok((grep { m{ /boot/grub2/grub\.cfg} && /timeout=45/ } @ipmi_cmds), 'grub.cfg timeout is set');
    ok((grep { m{/etc/default/grub} && /GRUB_TIMEOUT=45/ } @ipmi_cmds), 'GRUB_TIMEOUT is set');
    ok((grep { /^grub2-mkconfig / } @ipmi_cmds), 'grub.cfg is regenerated');
    ok(!(grep { m{loader\.conf|sdbootutil} } @ipmi_cmds), 'nothing systemd-boot specific is run');
};

for my $dst ('localhost', 'sut.example.com') {
    subtest "the loader.conf edit sets console-mode and timeout exactly once ($dst)" => sub {
        my $root = tempdir(CLEANUP => 1);
        make_path("$root/boot/loader");
        write_file("$root/boot/loader/loader.conf", "#timeout 3\nconsole-mode auto\ndefault sles-*\n");
        %sdboot_on = ($dst => 1);
        local $run_file_edits = 1;
        my $ok = eval { set_grub_terminal_and_timeout(dst_machine => $dst, root_dir => $root, timeout => 45); 1 };
        ok($ok, 'no command fails') or diag($@);
        my $conf = read_file("$root/boot/loader/loader.conf");
        my @timeout = $conf =~ /^\s*#?\s*(timeout.*)$/mg;
        my @console = $conf =~ /^\s*#?\s*(console-mode.*)$/mg;
        is_deeply(\@timeout, ['timeout 45'], 'one active timeout line with the new value');
        is_deeply(\@console, ['console-mode keep'], 'one console-mode line, set to keep');
        like($conf, qr/^default sles-\*$/m, 'other settings are kept');
    };
}

done_testing();
