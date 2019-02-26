# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Test installation of puppet master and slave on the same host
# Maintainer: Zaoliang Luo <zluo@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    select_console 'root-console';
    pkcon_quit;
    if (script_run('zypper se puppet') == 104 && is_sle('15+')) {
        return record_soft_failure 'bsc#1092498 - puppet disappeared from packagehub or was never added';
    }
    my $output      = "puppet cert list --all | grep -woh puppetslave.local > /dev/$serialdev";
    my $puppet_conf = <<"EOF";
zypper -n in puppet-server puppet
echo '127.0.0.2 puppetmaster.local puppetslave.local' >> /etc/hosts
echo 'server = puppetmaster.local' >> /etc/puppet/puppet.conf
echo 'certname = puppetslave.local' >> /etc/puppet/puppet.conf
echo '[master]' >> /etc/puppet/puppet.conf
echo 'certname = puppetmaster.local' >> /etc/puppet/puppet.conf
echo 'dns_alt_names = puppetmaster.local' >> /etc/puppet/puppet.conf
systemctl start puppetmaster
for i in {1..10}; do sleep 1 && systemctl is-active puppetmaster && systemctl start puppet && break; done
EOF
    assert_script_run($_) foreach (split /\n/, $puppet_conf);
    validate_script_output $output, sub { m/puppetslave\.local/ };
}
1;
