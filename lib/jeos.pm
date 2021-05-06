# Copyright (C) 2015-2020 SUSE LLC
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

package jeos;
use Mojo::Base qw(Exporter);
use testapi;
use utils qw(ensure_serialdev_permissions);
use power_action_utils qw(power_action);
use Utils::Backends qw(is_hyperv);
use version_utils qw(is_sle is_tumbleweed is_leap);
use bootloader_setup qw(change_grub_config grep_grub_settings grub_mkconfig set_framebuffer_resolution set_extrabootparams_grub_conf);

our @EXPORT = qw(expect_mount_by_uuid set_grub_gfxmode reboot_image);

sub expect_mount_by_uuid {
    return (is_hyperv || is_sle('>=15-sp2') || is_tumbleweed || is_leap('>=15.2'));
}

sub reboot_image {
    my ($self, $msg) = @_;
    power_action('reboot', textmode => 1);
    record_info('reboot', $msg);
    $self->wait_boot(bootloader_time => 150);
    $self->select_serial_terminal;
    ensure_serialdev_permissions;
}

# Set GRUB_GFXMODE to 1024x768
sub set_grub_gfxmode {
    change_grub_config('=.*', '=1024x768', 'GRUB_GFXMODE=');
    change_grub_config('^#',  '',          'GRUB_GFXMODE');
    change_grub_config('=.*', '=-1',       'GRUB_TIMEOUT') unless check_var('VIRSH_VMM_TYPE', 'linux');
    grep_grub_settings('^GRUB_GFXMODE=1024x768$');
    set_framebuffer_resolution;
    set_extrabootparams_grub_conf;
    grub_mkconfig;
}

1;
