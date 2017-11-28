# Copyright © 2017 SUSE LLC
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
package LTP::TestInfo;
use Mojo::Base 'OpenQA::Test::RunArgs';

our @EXPORT_OK = qw(testinfo);
use Exporter 'import';

has 'test';
has test_result_export => sub { die 'Require test_result_export hashref'; };

sub testinfo {
    __PACKAGE__->new(test_result_export => shift @_, @_);
}

1;
