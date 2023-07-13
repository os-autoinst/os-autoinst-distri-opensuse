# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Installer for test scripts running inside the tested virtual machine
# Maintainer: Martin Doucha <mdoucha@suse.cz>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use Mojo::JSON;
use Mojo::File 'path';

sub run {
    my ($self, $tinfo) = @_;
    my $podlist = $tinfo->test;
    my $path = get_required_var('CASEDIR') . '/tests';

    die "Pod list not provided" unless $podlist;

    my $tardata = qx{tar -C "$path" -cjf - test_pods};
    save_tmp_file('test_pods.tar.bz2', $tardata);
    $tardata = undef;
    select_serial_terminal;
    assert_script_run('pushd /tmp && rm -rf test_pods test_pods.tar.bz2');
    assert_script_run('wget --quiet -O test_pods.tar.bz2 ' . autoinst_url . '/files/test_pods.tar.bz2');
    assert_script_run('tar xjf test_pods.tar.bz2');
    assert_script_run('rm test_pods.tar.bz2 && popd');

    # Install pod dependencies
    my %dep_hash = (perl => 1);

    for my $podname (@$podlist) {
        my $script = path("$path/test_pods/$podname")->slurp;
        my @deplist;

        if ($script =~ m/^#\s*pod_package_deps:\s*(.*)$/m) {
            @deplist = split '\s*,\s*', $1;
        }

        for my $dep (@deplist) {
            $dep_hash{$dep} = 1;
        }
    }

    zypper_call 'in ' . join(' ', keys %dep_hash) if %dep_hash;
    assert_script_run("export _OPENQA_LOG_DIRECTORY='/tmp/openqa_logs'");

    for my $varname (qw(BACKEND DISTRI FLAVOR VERSION)) {
        my $value = get_var($varname);
        next if !defined $value;
        assert_script_run("export _OPENQA_ENV_$varname='$value'");
    }
}

sub test_flags {
    return {
        fatal => 1,
        milestone => 1
    };
}

1;
