# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: installed services SLEPOS test
# Maintainer: Pavel Sladek <psladek@suse.cz>

use base "basetest";
use strict;
use warnings;
use testapi;
use utils;


sub check_service {
    my $service = shift;
    bmwqemu::diag("checking service: '$service'");
    script_output("/etc/init.d/$service status");
    script_output("chkconfig --list $service | grep 3:on | grep 5:on");
}

sub run() {
    #check services on adminserver
    if (get_var('SLEPOS') =~ /^adminserver/) {
        check_service('ldap');
        check_service('rsyncd');
    }
    elsif (get_var('SLEPOS') =~ /^branchserver/) {
        my $basedn = script_output("grep BRANCH_LDAPBASE /etc/SLEPOS/branchserver.conf | cut -d= -f2-");
        $basedn =~ s/^"//;
        $basedn =~ s/"$//;
        #get bs services from ldap
        my $services
          = script_output(
"posAdmin --query --list --base $basedn --scService --scServiceStatus TRUE --scServiceStartScript | grep scServiceStartScript:|cut -d ' ' -f 2"
          );
        my $extdhcp   = script_output("posAdmin --query  --list --base $basedn --scLocation --scDhcpExtern ");
        my $nodhcpsrv = 0;
        $nodhcpsrv = 1 if $extdhcp =~ /scDhcpExtern: TRUE/;
        my @services = split('\n', $services);
        foreach my $srvc (@services) {
            $srvc =~ s/\s+$//;
            $srvc =~ s/^\s+//;
            next if $nodhcpsrv && ($srvc eq 'dhcpd');
            check_service($srvc);
        }
    }
}


sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
