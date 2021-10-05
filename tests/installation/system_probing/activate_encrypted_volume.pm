# Copyright 2021 SUSE LLC
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

# Summary: Test module to activate encrypted volume.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    my $encrypted_volume = $testapi::distri->get_encrypted_volume_activation();
    $encrypted_volume->enter_volume_encryption_password($password);
    $encrypted_volume->accept_password();
}

1;
