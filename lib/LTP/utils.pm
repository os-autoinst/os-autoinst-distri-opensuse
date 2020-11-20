# Copyright © 2020 SUSE LLC
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

# Summary: LTP helper functions
# Maintainer: Martin Doucha <mdoucha@suse.cz>

package LTP::utils;

use base Exporter;
use strict;
use warnings;
use testapi;
use LTP::TestInfo 'testinfo';
use main_ltp qw(loadtest_kernel shutdown_ltp);
use File::Basename 'basename';

our @EXPORT = qw(prepare_ltp_env schedule_tests);

# Set up basic shell environment for running LTP tests
sub prepare_ltp_env {
    my $ltp_env = get_var('LTP_ENV');

    assert_script_run('export LTPROOT=/opt/ltp; export LTP_COLORIZE_OUTPUT=n TMPDIR=/tmp PATH=$LTPROOT/testcases/bin:$PATH');

    # setup for LTP networking tests
    assert_script_run("export PASSWD='$testapi::password'");

    my $block_dev = get_var('LTP_BIG_DEV');
    if ($block_dev && get_var('NUMDISKS') > 1) {
        assert_script_run("lsblk -la; export LTP_BIG_DEV=$block_dev");
    }

    if ($ltp_env) {
        $ltp_env =~ s/,/ /g;
        script_run("export $ltp_env");
    }

    assert_script_run('cd $LTPROOT/testcases/bin');
}

sub read_runfile {
    my ($runfile_path) = @_;
    my $basename = basename($runfile_path);
    my @ret;

    upload_asset($runfile_path);
    open my $rf, "assets_private/$basename" or die "Cannot open runfile $basename: $!";

    while (my $line = <$rf>) {
        push @ret, $line;
    }

    close($rf);
    return \@ret;
}

sub schedule_tests {
    my ($cmd_file) = @_;

    my $test_result_export = {
        format      => 'result_array:v2',
        environment => {},
        results     => []};
    my $cmd_pattern = get_var('LTP_COMMAND_PATTERN') || '.*';
    my $cmd_exclude = get_var('LTP_COMMAND_EXCLUDE') || '$^';
    my $environment = {
        product     => get_var('DISTRI') . ':' . get_var('VERSION'),
        revision    => get_var('BUILD'),
        flavor      => get_var('FLAVOR'),
        arch        => get_var('ARCH'),
        backend     => get_var('BACKEND'),
        kernel      => '',
        libc        => '',
        gcc         => '',
        harness     => 'SUSE OpenQA',
        ltp_version => ''
    };
    my $ver_linux_out = script_output("cat /tmp/ver_linux_before.txt");
    if ($ver_linux_out =~ qr'^Linux\s+(.*?)\s*$'m) {
        $environment->{kernel} = $1;
    }
    if ($ver_linux_out =~ qr'^Linux C Library\s*>?\s*(.*?)\s*$'m) {
        $environment->{libc} = $1;
    }
    if ($ver_linux_out =~ qr'^Gnu C\s*(.*?)\s*$'m) {
        $environment->{gcc} = $1;
    }
    $environment->{ltp_version}        = script_output('touch /opt/ltp_version; cat /opt/ltp_version');
    $test_result_export->{environment} = $environment;

    if ($cmd_file =~ m/ltp-aiodio.part[134]/) {
        loadtest_kernel 'create_junkfile_ltp';
    }

    if ($cmd_file =~ m/lvm\.local/) {
        loadtest_kernel 'ltp_init_lvm';
    }

    for my $name (split(/,/, $cmd_file)) {
        if ($name eq 'openposix') {
            parse_openposix_runfile($name,
                read_runfile('/root/openposix-test-list'),
                $cmd_pattern, $cmd_exclude, $test_result_export);
        }
        else {
            parse_runtest_file($name, read_runfile("/opt/ltp/runtest/$name"),
                $cmd_pattern, $cmd_exclude, $test_result_export);
        }
    }

    shutdown_ltp(run_args => testinfo($test_result_export));
}

sub parse_openposix_runfile {
    my ($name, $cmds, $cmd_pattern, $cmd_exclude, $test_result_export) = @_;

    for my $line (@$cmds) {
        chomp($line);
        if ($line =~ m/$cmd_pattern/ && !($line =~ m/$cmd_exclude/)) {
            my $test  = {name => basename($line, '.run-test'), command => $line};
            my $tinfo = testinfo($test_result_export, test => $test, runfile => $name);
            loadtest_kernel('run_ltp', name => $test->{name}, run_args => $tinfo);
        }
    }
}

sub parse_runtest_file {
    my ($name, $cmds, $cmd_pattern, $cmd_exclude, $test_result_export) = @_;

    for my $line (@$cmds) {
        next if ($line =~ /(^#)|(^$)/);

        #Command format is "<name> <command> [<args>...] [#<comment>]"
        if ($line =~ /^\s* ([\w-]+) \s+ (\S.+) #?/gx) {
            next if (check_var('BACKEND', 'svirt') && ($1 eq 'dnsmasq' || $1 eq 'dhcpd'));    # poo#33850
            my $test  = {name => $1, command => $2};
            my $tinfo = testinfo($test_result_export, test => $test, runfile => $name);
            if ($test->{name} =~ m/$cmd_pattern/ && !($test->{name} =~ m/$cmd_exclude/)) {
                loadtest_kernel('run_ltp', name => $test->{name}, run_args => $tinfo);
            }
        }
    }
}

1;
