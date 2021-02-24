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

# Summary: Enable libyui for firstboot. Temporary module until 
# https://progress.opensuse.org/issues/90368 is done.

# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "installbasetest";
use testapi;

use testapi;
use registration "add_suseconnect_product";
use version_utils "is_sle";

sub run {
    add_suseconnect_product('sle-module-development-tools') if is_sle;
    YuiRestClient::setup_libyui_firstboot();
}

1;
