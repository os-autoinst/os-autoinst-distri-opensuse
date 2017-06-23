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
# Maintainer: Dumitru Gutu <dgutu@suse.de>

use base "consoletest";
use strict;
use testapi;
use utils;

sub run() {
    select_console 'root-console';
    pkcon_quit;
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
systemctl start puppet
EOF
    assert_script_run($_) foreach (split /\n/, $puppet_conf);
    validate_script_output $output, sub { m/puppetslave\.local/ };
}
1;
# vim: set sw=4 et:
