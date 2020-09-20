# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
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

# Summary: The class introduces all accessing methods for Encrypt
# Page of Expert Partitioner Wizard, that are common for all the versions of the
# page (e.g. for both Libstorage and Libstorage-NG).
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::EncryptPage;
use strict;
use warnings;
use testapi;
use parent 'Installation::WizardPage';

use constant {
    ENCRYPT => 'encrypt_password',
};

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        password_textfield        => $args->{password_textfield},
        password_verify_textfield => $args->{password_verify_textfield}
    }, $class;
}

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(ENCRYPT);
}

sub enter_password {
    my ($self) = shift;
    assert_screen(ENCRYPT);
    send_key($self->{password_textfield});
    type_password();
}

sub enter_password_confirmation {
    my ($self) = shift;
    assert_screen(ENCRYPT);
    send_key($self->{password_verify_textfield});
    type_password();
}

1;
