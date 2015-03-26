# Copyright (C) 2014 SUSE Linux Products GmbH
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
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use base 'basetest';
use testapi;
use lockapi;
use mmapi;

sub run {
    $testapi::username = "root";
    $testapi::password = "linux";


    assert_screen( "autoyast-system-login-console", 300 );
    
    type_string "$username\n";
    sleep 5;
#        assert_screen "password-prompt", 10;
    type_password;
    type_string "\n";
    sleep 5;
    
    
    script_output("
        curl -f -v " . autoinst_url . "/data/supportserver/proxy.conf | sed -e 's|#AUTOINST_URL#|" . autoinst_url . "|g' >/etc/apache2/vhosts.d/proxy.conf
        systemctl restart apache2.service
    ");
    
    mutex_create('pxeboot_ready');
    
    while (1) {
        my $s = get_children_by_state('scheduled');
        my $r = get_children_by_state('running');
        my $n = @$s + @$r;

        print "Waiting for $n jobs to finish\n";

        use Data::Dumper;
        print Dumper($s, $r);

        last if $n == 0;
        sleep 1;
    }
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { important => 1, fatal => 1 };
}

1;

# vim: set sw=4 et:
