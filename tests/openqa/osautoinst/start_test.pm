# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Clone an openQA job from O3
# Maintainer: Dominik Heidler <dheidler@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;

sub run {
    my $arch       = get_required_var('ARCH');
    my $ttest      = 'minimalx';
    my $openqa_url = get_var('OPENQA_HOST_URL', 'https://openqa.opensuse.org');
    # aarch64 does not support nested virt, huge pages are not configured and 'gic_version=host' and host cpu options are only usable with KVM
    my $clone_options = ($arch =~ /aarch64/) ? "QEMU_NO_KVM=1 QEMU_HUGE_PAGES_PATH='' QEMUMACHINE=virt QEMUCPU='cortex-a72'" : "";
    my $cmd           = <<"EOF";
last_tw_build=\$(openqa-client --host $openqa_url assets get | sed -n 's/^.*name.*Tumbleweed-NET-$arch-Snapshot\\([0-9]\\+\\)-Media.*\$/\\1/p' | sort -n | tail -n 1)
echo "Last Tumbleweed build on openqa.opensuse.org: \$last_tw_build"
[ ! -z \$last_tw_build ]
zypper -n in jq
job_id=\$(openqa-client --host $openqa_url --json-output jobs get version=Tumbleweed scope=relevant arch=$arch build=\$last_tw_build flavor=NET latest=1 | jq '.jobs | .[] | select(.test == "$ttest") | .id')
echo "Job Id: \$job_id"
[ ! -z \$job_id  ]
echo "Scenario: $arch-$ttest-NET: \$job_id"
openqa-clone-job --from $openqa_url \$job_id $clone_options
EOF
    assert_script_run($_) foreach (split /\n/, $cmd);
}

sub test_flags {
    return {fatal => 1};
}

1;
