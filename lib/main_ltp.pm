# Copyright © 2017-2018 SUSE LLC
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
use testapi qw(check_var get_var);
use autotest;
use utils;
use LTP::TestInfo qw(testinfo);
use File::Basename 'basename';
use main_common qw(load_bootloader_s390x boot_hdd_image get_ltp_tag);
use 5.018;

our @EXPORT = 'load_kernel_tests';

sub loadtest {
    my ($test, %args) = @_;
    autotest::loadtest("tests/kernel/$test.pm", %args);
}

sub shutdown_ltp {
    loadtest('proc_sys_dump') if get_var('PROC_SYS_DUMP');
    loadtest('shutdown_ltp', @_);
}

sub parse_openposix_runfile {
    my ($path, $cmd_pattern, $cmd_exclude, $test_result_export) = @_;

    open(my $rfile, $path) or die "Can not open runfile asset $path: $!";    ## no critic
    while (my $line = <$rfile>) {
        chomp($line);
        if ($line =~ m/$cmd_pattern/ && !($line =~ m/$cmd_exclude/)) {
            my $test = {name => basename($line, '.run-test'), command => $line};
            my $tinfo = testinfo($test_result_export, test => $test);
            loadtest('run_ltp', name => $test->{name}, run_args => $tinfo);
        }
    }
}

sub parse_runtest_file {
    my ($path, $cmd_pattern, $cmd_exclude, $test_result_export) = @_;

    open(my $rfile, $path) or die "Can not open runtest asset $path: $!";    ## no critic
    while (my $line = <$rfile>) {
        next if ($line =~ /(^#)|(^$)/);

        #Command format is "<name> <command> [<args>...] [#<comment>]"
        if ($line =~ /^\s* ([\w-]+) \s+ (\S.+) #?/gx) {
            next if (check_var('BACKEND', 'svirt') && ($1 eq 'dnsmasq' || $1 eq 'dhcpd'));    # poo#33850
            my $test = {name => $1, command => $2};
            my $tinfo = testinfo($test_result_export, test => $test);
            if ($test->{name} =~ m/$cmd_pattern/ && !($test->{name} =~ m/$cmd_exclude/)) {
                loadtest('run_ltp', name => $test->{name}, run_args => $tinfo);
            }
        }
    }
}

sub loadtest_from_runtest_file {
    my $name               = get_var('LTP_COMMAND_FILE');
    my $path               = get_var('ASSETDIR') . '/other';
    my $tag                = get_ltp_tag();
    my $cmd_pattern        = get_var('LTP_COMMAND_PATTERN') || '.*';
    my $cmd_exclude        = get_var('LTP_COMMAND_EXCLUDE') || '$^';
    my $test_result_export = {
        format      => 'result_array:v2',
        environment => {},
        results     => []};

    loadtest('boot_ltp', run_args => testinfo($test_result_export));
    if (get_var('LTP_COMMAND_FILE') =~ m/ltp-aiodio.part[134]/) {
        loadtest 'create_junkfile_ltp';
    }

    if ($name eq 'openposix') {
        parse_openposix_runfile($path . '/openposix-test-list-' . $tag, $cmd_pattern, $cmd_exclude, $test_result_export);
    }
    else {
        parse_runtest_file($path . "/ltp-$name-" . $tag, $cmd_pattern, $cmd_exclude, $test_result_export);
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
    load_bootloader_s390x();

    if (get_var('INSTALL_LTP')) {
        if (get_var('INSTALL_KOTD')) {
            loadtest 'install_kotd';
        }
        elsif (get_var('CHANGE_KERNEL_REPO') ||
            get_var('CHANGE_KERNEL_PKG') ||
            get_var('ASSET_CHANGE_KERNEL_RPM')) {
            loadtest 'change_kernel';
        }
        if (get_var('FLAVOR', '') =~ /Incidents-Kernel$/) {
            loadtest 'update_kernel';
        }
        loadtest 'install_ltp';
        if (get_var('LTP_INSTALL_REBOOT')) {
            loadtest 'boot_ltp';
        }
        shutdown_ltp();
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
    }
    elsif (get_var('NVMFTESTS')) {
        boot_hdd_image();
        loadtest 'nvmftests';
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
    }

    if (check_var('BACKEND', 'svirt') && get_var('PUBLISH_HDD_1')) {
        loadtest '../shutdown/svirt_upload_assets';
    }
}
