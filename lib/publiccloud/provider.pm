# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Base helper class for public cloud
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

package publiccloud::provider;
use Mojo::Base -base;

has key_id     => undef;
has key_secret => undef;
has region     => undef;
has prefix     => 'openqa';

=head1 METHODS
 
=head2 init
 
Needs provider specific credentials, e.g. key_id, key_secret, region.

=cut
sub init {
    die('init() isn\'t implemented');
}


=head2 find_img

Retrieves the image-id by given image C<name>.

=cut
sub find_img {
    die('find_image() isn\'t implemented');
}

=head2 upload_image

Upload a image to the CSP. Required parameter is the
location of the C<image> file.

Retrieves the image-id after upload or die.

=cut
sub upload_image {
    die('find_image() isn\'t implemented');
}

=head2 cleanup

This method is called called after each test on failure or success.

=cut
sub cleanup {
}

1;

