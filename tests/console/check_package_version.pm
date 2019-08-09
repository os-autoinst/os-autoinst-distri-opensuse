# Copyright (C) 2019 SUSE LLC
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
# Summary: Check package version only for sles12sp5 migration scenarios
# Maintainer: Yutao Wang <yuwang@suse.com>

use base "basetest";
use strict;
use warnings;
use version;
use testapi;
use utils 'zypper_call';

my %package = (
    autofs              => '5.1.5',
    openscap            => '1.3.0',
    augeas              => '1.0.0',
    'freeradius-server' => '3.0.18',
    gpgme               => '1.9.0',
    'libgpg-error0'     => '1.17',
);

my %package_s390x = (
    'libnuma-devel' => '2.0.12',
);

sub cmp_version {
    my ($old, $new) = @_;
    my @newv = split(/-/, $new);
    my $v1   = version->parse($old);
    my $v2   = version->parse($newv[0]);
    return $v1 <= $v2;
}

sub cmp_packages {
    my ($pcks, $pckv) = @_;
    record_info($pcks, "$pcks version check after migration");
    my $output = script_output("zypper se -s $pcks | grep -w $pcks | head -1 | awk -F '|' '{print \$4}'", 80);
    if ($output ne '' && !cmp_version($pckv, $output)) {
        record_info("Version Failed", "The $pcks version is $output, but request is $pckv");
        return $pcks;
    }
    return $pcks if ($output eq '');
}

sub run {

    select_console 'root-console';

    my @failed_pcks;
    foreach my $key (keys %package) {
        my $pcks = cmp_packages($key, $package{$key});
        push @failed_pcks, $pcks if $pcks;
    }

    if (get_var('ARCH') =~ /s390x/) {
        foreach my $key (keys %package_s390x) {
            my $pcks = cmp_packages($key, $package_s390x{$key});
            push @failed_pcks, $pcks if $pcks;
        }
    }

    assert_script_run('python3 --version', 30);
    die "there are failed packages" if @failed_pcks;
}

sub test_flags {
    return {fatal => 0};
}

1;
