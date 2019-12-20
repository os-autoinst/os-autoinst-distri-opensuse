# SUSE's openQA tests
#
# Copyright © 2019-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Launcher for test scripts running inside the tested virtual machine
# Maintainer: Martin Doucha <mdoucha@suse.cz>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use Mojo::JSON;
use Mojo::File 'path';

sub run {
    my ($self, $tinfo) = @_;
    my $podname = $tinfo->test;

    die "No pod name provided" unless $podname;

    my $casedir = get_required_var('CASEDIR');
    my $script  = path("$casedir/tests/test_pods/$podname")->slurp;
    my $timeout = 60;
    $timeout = $1 if ($script =~ m/^#\s*pod_timeout:\s*(\d+)\s*$/m);

    assert_script_run("pushd /tmp/test_pods");
    my $ret = script_run("./$podname", timeout => $timeout);
    die if !defined($ret);
    my $logfile = upload_logs('/tmp/openqa_logs/testlog.json');
    script_run('rm -r /tmp/openqa_logs');

    my $json     = path("ulogs/$logfile")->slurp;
    my $testlist = Mojo::JSON::decode_json($json);

    for my $test (@$testlist) {
        my $output = "# $$test{test}\n\n";
        my $result = $$test{result};
        $output .= "# stdout:\n$$test{stdout}\n\n";
        $output .= "# stderr:\n$$test{stderr}";
        $self->record_resultfile($$test{test}, $output, result => $result);

        if ($result) {
            $self->{subtest_results}{$result} //= 0;
            $self->{subtest_results}{$result}++;
        }
    }
}

sub done {
    my $self = shift;
    script_run('popd');

    for my $result ('fail', 'softfail', 'ok') {
        if ($self->{subtest_results}{$result}) {
            $self->{result} //= $result;
            last;
        }
    }

    $self->SUPER::done;
}

1;
