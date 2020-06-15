# Copyright (C)2019-2020 SUSE LLC
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
use utils qw(systemctl zypper_call);
use Mojo::Util 'trim';

my %package = (
    xrdp              => ['0.9.6',   'jsc#9612'],
    xorgxrdp          => ['0.2.6',   'jsc#9612'],
    systemtap         => ['3.2',     'jsc#9205'],
    'multipath-tools' => ['0.7.3',   'jsc#8762'],
    'rdma-core'       => ['16.9',    'jsc#8399'],
    libica            => ['3.6.0',   'jsc#7481'],
    libvirt           => ['5.8',     'jsc#7467'],
    'virt-manager'    => ['2.2.0',   'jsc#7453'],
    openCryptoki      => ['3.12.0',  'jsc#7444'],
    qemu              => ['4.1.0',   'jsc#7424'],
    libdfp1           => ['1.0.14',  'jsc#7401'],
    'python3-kiwi'    => ['9.18.16', 'jsc#7185'],
    iprutils          => ['2.4.15',  'jsc#7728'],
    libservicelog     => ['1.1.18',  'jsc#7727'],
    'nvme-cli'        => ['1.5.0',   'jsc#7726'],
    lsvpd             => ['1.7.8',   'jsc#7705'],
    openssl           => ['1.1.1',   'jsc#7701'],
    valgrind          => ['3.15.0',  'jsc#7664'],
    apache2           => ['2.4.42',  'jsc#7655'],
    'libp11-kit0'     => ['0.4.10',  'jsc#10686'],
    'smc-tools'       => ['1.2.2',   'jsc#7878'],
    'virt-manager'    => ['2.2.0',   'jsc#7875'],
    qclib             => ['1.4.2',   'jsc#7869'],
    'openssl-ibmca'   => ['2.0.4',   'jsc#7854']
);

sub cmp_version {
    my ($old, $new) = @_;
    my @newv = split(qr/-|\+/, $new);
    $newv[0] =~ s/[a-zA-Z]//g;
    my $v1 = version->parse($old);
    my $v2 = version->parse($newv[0]);
    return $v1 <= $v2;
}

sub cmp_packages {
    my ($pcks, $pckv, $jsc) = @_;
    record_info($pcks, "$pcks version check after migration");
    my $output = script_output("zypper se -xs $pcks | grep -w $pcks | head -1 | awk -F '|' '{print \$4}'", 100, proceed_on_failure => 1);
    my $out    = '';
    for my $line (split(/\r?\n/, $output)) {
        if (trim($line) =~ m/^\d+\.\d+(\.\d+)?/) {
            $out = $line;
            record_soft_failure("$jsc, The $pcks version is $out, but request is $pckv") if (!cmp_version($pckv, $out));
        }
    }
    if ($out eq '') {
        record_soft_failure("$jsc, The $pcks is not existed");
    }
}

sub run {

    select_console 'root-console';

    foreach my $key (keys %package) {
        my $pcks = cmp_packages($key, $package{$key}[0], $package{$key}[1]);
    }

}

sub test_flags {
    return {fatal => 0};
}

1;
