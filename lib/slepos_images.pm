package slepos_images;
use base Exporter;
use Exporter;
use testapi;


our @EXPORT = qw/
  split_image_name
  get_asset_name
  get_image_from_asset
  upload_slepos_image
  get_image_suffix
  /;

our $img_suffix = 'tar.bz2';


#minimal-3.4.0 -> minimal
sub split_image_name {
    my ($image) = @_;
    $image =~ /^(.*)-([^-]*)$/;
    return ($1, $2);    #basename, version
}

#asset dwl idx -> asset variable name
sub get_asset_name {
    my ($idx) = @_;
    return 'ASSET_' . $idx;
}

#ASSET_0=0012340-minimal-3.4.0.tar.bz2 -> minimal-3.4.0
#ASSET_1=graphical-4.0.0.tar.bz2 -> graphical-4.0.0
sub get_image_from_asset {
    my ($asset) = @_;
    my $image = get_var($asset);
    $image =~ s/^\d+-//;                #remove if private assets reference
    $image =~ s/\Q.$img_suffix\E$//;    #remove suffix
    return $image;
}

#assume in correct dir
sub upload_slepos_image {
    my ($target, $type, $linux32) = @_;
    if ($type eq 'pxe') {
        script_output "tar -cjf $target.$img_suffix /var/lib/SLEPOS/system/images/$target/", 2000;
        upload_asset "$target.$img_suffix",                                                  'public';
    }
    elsif ($type eq 'oem') {
        my ($name, $ver) = split_image_name($target);
        $linux32 = $linux32 ? 'linux32' : '';
        my $arch = $linux32 ? 'i686' : 'x86_64';
        upload_asset "/var/lib/SLEPOS/system/images/$target/$name.$arch-$ver.raw", 'public';
    }
    #todo: offline type
}

sub get_image_suffix {
    return $img_suffix;
}


1;
