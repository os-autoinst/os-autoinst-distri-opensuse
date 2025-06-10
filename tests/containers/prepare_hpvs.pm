# SUSE's openQA tests
#
# Copyright 2022-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: IBM HPVS container runner
#   A smoke test that BCI containers can run in IBM's Hyper Protect Platform
# Maintainer: QE-C team <qa-c@suse.de>

use strict;
use warnings;
use Mojo::Base qw(consoletest);
use utils qw(script_retry file_content_replace);
use version_utils;
use testapi;
use Mojo::JSON qw(decode_json);
use serial_terminal 'select_serial_terminal';

my $ibm = {
    api => get_var('IBM_API'),
    region => 'eu-gb',
    ingestionKey => get_var('IBM_LOG_KEY'),
    instance => 'openqa-',
    vpc => 'vpc-openqa-testing'
};

sub ibmcloud {
    assert_script_run("ibmcloud @_");
}

sub get_image_digest {
    my $img = shift;
    script_retry("podman pull --arch=s390x registry.suse.com/bci/$img", retry => 3, delay => 30);

    my $o = decode_json(script_output("podman inspect $img"));
    return $o->[0]->{Digest};
}

sub _create_compose {
    my $img = shift;
    my $tag = get_var('VERSION') =~ s/-SP/\./r;
    my $img_w_tag = "$img:$tag";
    assert_script_run("curl -f -v -O " . data_url("containers/ibm_hpvs/$img"));

    my $dgst = get_image_digest($img_w_tag);
    file_content_replace($img, IMG => $img_w_tag, DGST => $dgst);
    record_info('compose', script_output("cat $img"));

    assert_script_run "mv $img docker-compose.yaml";
    assert_script_run 'tar czvf compose.tgz docker-compose.yaml';
    assert_script_run 'base64 -w0 compose.tgz > compose.b64';
    my $o = script_output('cat compose.b64');
    chomp $o;

    return $o;
}

sub create_workload {
    my $img = shift;
    my $archive = _create_compose($img);
    my $template = '/tmp/workload.yaml';

    # download workload contract template
    assert_script_run("curl -f -v -o $template " . data_url("containers/ibm_hpvs/workload.yaml"));
    file_content_replace($template, INGESTIONKEY => $ibm->{ingestionKey}, ARCHIVE => $archive);

    return sprintf('--user-data @%s', $template);
}

sub find_entity {
    my $q = shift;
    my $search = {
        image => {
            query => 'ibmcloud is images --status available --user-data-format cloud_init --output json',
            regex => qr/ibm-hyper-protect.*s390x/i
        },
        net => {
            query => 'ibmcloud is subnets --output json',
            regex => qr/^sn-20240729-\d{2}/
        },
        'float-ip' => {
            query => 'ibmcloud is ips --output json',
            regex => qr/^openqa-ips$/
        }
    };

    my $res;
    my $raw = decode_json(script_output($search->{$q}->{query}));
    foreach (@{$raw}) {
        if ($_->{name} =~ $search->{$q}->{regex}) {
            $res = $_;
            last;
        }
    }

    return $res;
}

sub run {
    select_serial_terminal();
    $ibm->{instance} .= lc(sprintf("%08X", rand(0xFFFFFFFF)));

    # install ibm cloud cli
    script_retry('curl -fsSL https://clis.cloud.ibm.com/install/linux -o IBMCloud.sh', retry => 3, delay => 30);
    assert_script_run('sh -x IBMCloud.sh');
    assert_script_run('which ibmcloud');

    # login and install VPC tools
    ibmcloud("config  --color false");
    ibmcloud("login -a https://cloud.ibm.com -r $ibm->{region} --apikey $ibm->{api}");
    ibmcloud('target -g Default');
    ibmcloud("resources");
    ibmcloud("plugin install vpc-infrastructure");

    # find hyper-protect s390x image
    my $image = find_entity('image');

    # find pre-defined subnet in VPC
    my $sub = find_entity('net');

    if (!$image || !$sub) {
        die "We are missing image name or subnet";
    }

    # prepare instance
    my $eth0 = qq[--primary-network-interface '{"name": "eth0", "allow_ip_spoofing": false, "subnet": {"id":"$sub->{id}"}}'];
    my $user_data = create_workload('bci-busybox');
    ibmcloud("is instance-create $ibm->{instance} $ibm->{vpc} $ibm->{region}-1 bz2e-1x4 --image $image->{name} $eth0 $user_data");

    # load pre-defined public ip
    my $fip = find_entity('float-ip');
    ibmcloud("is floating-ip-update $fip->{id} --nic eth0 --in $ibm->{instance}");

    # test needs to wait while hyper protect services are finished
    my $i;
    for ($i = 0; $i < 5; $i++) {
        sleep 30;
        my $state = decode_json(script_output("ibmcloud is instance $ibm->{instance} --output json", proceed_on_failure => 1));
        if ($state->{status} eq 'running') {
            last;
        }
    }

    if ($i == 5) {
        ibmcloud "is instance $ibm->{instance}";
        die "Instance $ibm->{instance} hasn't booted!";
    }

    script_retry("nc -zvw10 $fip->{address} 8222", retry => 5, delay => 45);
}

sub _cleanup {
    ibmcloud("is instance-delete -f $ibm->{instance}");
    upload_logs('./docker-compose.yaml');
    upload_logs('/tmp/workload.yaml');
}

sub post_fail_hook {
    _cleanup;
}

sub post_run_hook {
    _cleanup;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
