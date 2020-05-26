## no critic (Strict)
# Copyright © 2017-2020 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# See kernel/install_ltp.pm and kernel/run_ltp.pm for documentation.
package main_ltp;
use base 'Exporter';
use Exporter;
use testapi qw(check_var get_required_var get_var);
use autotest;
use Archive::Tar;
use utils;
use LTP::TestInfo 'testinfo';
use File::Basename 'basename';
use main_common qw(boot_hdd_image load_bootloader_s390x load_kernel_baremetal_tests);
use 5.018;
use Utils::Backends 'is_pvm';
# FIXME: Delete the "## no critic (Strict)" line and uncomment "use warnings;"
# use warnings;

our @EXPORT = qw(
  get_ltp_tag
  load_kernel_tests
  loadtest_from_runtest_file
);

sub loadtest {
    my ($test, %args) = @_;
    autotest::loadtest("tests/kernel/$test.pm", %args);
}

sub shutdown_ltp {
    loadtest('proc_sys_dump') if get_var('PROC_SYS_DUMP');
    loadtest('shutdown_ltp', @_);
}

sub parse_openposix_runfile {
    my ($path, $name, $cmd_pattern, $cmd_exclude, $test_result_export) = @_;

    open(my $rfile, $path) or die "Can not open runfile asset $path: $!";    ## no critic (InputOutput::ProhibitTwoArgOpen)
    while (my $line = <$rfile>) {
        chomp($line);
        if ($line =~ m/$cmd_pattern/ && !($line =~ m/$cmd_exclude/)) {
            my $test  = {name => basename($line, '.run-test'), command => $line};
            my $tinfo = testinfo($test_result_export, test => $test, runfile => $name);
            loadtest('run_ltp', name => $test->{name}, run_args => $tinfo);
        }
    }
}

sub parse_runtest_file {
    my ($path, $name, $cmd_pattern, $cmd_exclude, $test_result_export) = @_;

    open(my $rfile, $path) or die "Can not open runtest asset $path: $!";    ## no critic (InputOutput::ProhibitTwoArgOpen)
    while (my $line = <$rfile>) {
        next if ($line =~ /(^#)|(^$)/);

        #Command format is "<name> <command> [<args>...] [#<comment>]"
        if ($line =~ /^\s* ([\w-]+) \s+ (\S.+) #?/gx) {
            next if (check_var('BACKEND', 'svirt') && ($1 eq 'dnsmasq' || $1 eq 'dhcpd'));    # poo#33850
            my $test  = {name => $1, command => $2};
            my $tinfo = testinfo($test_result_export, test => $test, runfile => $name);
            if ($test->{name} =~ m/$cmd_pattern/ && !($test->{name} =~ m/$cmd_exclude/)) {
                loadtest('run_ltp', name => $test->{name}, run_args => $tinfo);
            }
        }
    }
}

sub get_ltp_tag {
    my $tag = get_var('LTP_RUNTEST_TAG');

    if (!defined $tag) {
        if (defined get_var('HDD_1')) {
            $tag = get_var('PUBLISH_HDD_1');
            $tag = get_var('HDD_1') if (!defined $tag);
            $tag = basename($tag);
        } else {
            $tag = get_var('DISTRI') . '-' . get_var('VERSION') . '-' . get_var('ARCH') . '-' . get_var('BUILD') . '-' . get_var('FLAVOR') . '@' . get_var('MACHINE');
        }
    }
    return $tag;
}

sub loadtest_from_runtest_file {
    my $namelist           = get_var('LTP_COMMAND_FILE');
    my $archive            = shift || get_var('ASSET_1');
    my $unpack_path        = './runtest-files';
    my $cmd_pattern        = get_var('LTP_COMMAND_PATTERN') || '.*';
    my $cmd_exclude        = get_var('LTP_COMMAND_EXCLUDE') || '$^';
    my $test_result_export = {
        format      => 'result_array:v2',
        environment => {},
        results     => []};

    if (!$archive) {
        my $tag = get_ltp_tag();
        $archive = get_var('ASSETDIR') . "/other/runtest-files-$tag.tar.gz";
    }

    loadtest('boot_ltp', run_args => testinfo($test_result_export));
    if (get_var('LTP_COMMAND_FILE') =~ m/ltp-aiodio.part[134]/) {
        loadtest 'create_junkfile_ltp';
    }

    if (get_var('LTP_COMMAND_FILE') =~ m/lvm\.local/) {
        loadtest 'ltp_init_lvm';
    }

    mkdir($unpack_path, 0755);
    my $tar = Archive::Tar->new();
    $tar->read($archive) || die "tar read failed $? $!";
    $tar->setcwd($unpack_path);
    $tar->extract() || die "tar extract failed $? $!";

    for my $name (split(/,/, $namelist)) {
        if ($name eq 'openposix') {
            parse_openposix_runfile("$unpack_path/openposix-test-list", $name, $cmd_pattern, $cmd_exclude, $test_result_export);
        }
        else {
            parse_runtest_file("$unpack_path/$name", $name, $cmd_pattern, $cmd_exclude, $test_result_export);
        }
    }

    shutdown_ltp(run_args => testinfo($test_result_export));
}

# Replace loadtest_from_runtest_file with this to stress test reverting to
# snapshots
sub stress_snapshots {
    my $count = 100;

    for (my $i = 0; $i < $count / 2; $i++) {
        # This will always fail and revert to the previous milestone, which
        # will either be boot_ltp or write_random#$i
        loadtest('run_ltp');
        loadtest('write_random');
    }
}

sub load_kernel_tests {
    if (get_var('LTP_BAREMETAL') && get_var('INSTALL_LTP')) {
        load_kernel_baremetal_tests();
    } else {
        load_bootloader_s390x();
    }

    loadtest "../installation/bootloader" if is_pvm;

    if (get_var('INSTALL_LTP')) {
        if (get_var('INSTALL_KOTD')) {
            loadtest 'install_kotd';
        }
        elsif (get_var('CHANGE_KERNEL_REPO') ||
            get_var('CHANGE_KERNEL_PKG') ||
            get_var('ASSET_CHANGE_KERNEL_RPM')) {
            loadtest 'change_kernel';
        }
        if (get_var('FLAVOR', '') =~ /Incidents-Kernel/) {
            loadtest 'update_kernel';
        }
        loadtest 'install_ltp';
        # If LTP_COMMAND_FILE is set, boot_ltp() and shutdown_ltp() will be added
        # later by install_ltp task.
        if (!get_var('LTP_COMMAND_FILE')) {
            if (get_var('LTP_INSTALL_REBOOT')) {
                loadtest 'boot_ltp';
            }
            shutdown_ltp();
        }
    }
    elsif (get_var('LTP_COMMAND_FILE')) {
        if (get_var('INSTALL_KOTD')) {
            loadtest 'install_kotd';
        }
        elsif (get_var('CHANGE_KERNEL_REPO') ||
            get_var('CHANGE_KERNEL_PKG') ||
            get_var('ASSET_CHANGE_KERNEL_RPM')) {
            loadtest 'change_kernel';
        }

        loadtest_from_runtest_file();
    }
    elsif (get_var('QA_TEST_KLP_REPO')) {
        if (get_var('INSTALL_KOTD')) {
            loadtest 'install_kotd';
        }
        loadtest 'boot_ltp';
        loadtest 'qa_test_klp';
    }
    elsif (get_var('VIRTIO_CONSOLE_TEST')) {
        loadtest 'virtio_console';
        loadtest 'virtio_console_long_output';
    }
    elsif (get_var('BLKTESTS')) {
        boot_hdd_image();
        loadtest 'blktests';
    }
    elsif (get_var('TRINITY')) {
        if (get_var('INSTALL_KOTD')) {
            loadtest 'install_kotd';
        }
        elsif (get_var('CHANGE_KERNEL_REPO') ||
            get_var('CHANGE_KERNEL_PKG') ||
            get_var('ASSET_CHANGE_KERNEL_RPM')) {
            loadtest 'change_kernel';
        }
        else {
            boot_hdd_image();
        }
        loadtest "trinity";
    } elsif (get_var('NUMA_IRQBALANCE')) {
        boot_hdd_image();
        loadtest 'numa_irqbalance';
    }

    if (check_var('BACKEND', 'svirt') && get_var('PUBLISH_HDD_1')) {
        loadtest '../shutdown/svirt_upload_assets';
    }
}
