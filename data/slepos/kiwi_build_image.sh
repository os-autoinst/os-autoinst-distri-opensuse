#!/bin/bash
### User settings

IMAGE_PATH='/var/lib/SLEPOS/system'
SLEPOS_TEMPLATE_PATH='/usr/share/kiwi/image/SLEPOS'

ROOT_NAME="root"
ROOT_REAL_NAME="root"
ROOT_GROUP_NAME="root"
ROOT_GID="0"
ROOT_UID="0"
ROOT_HOME="/root"


# NOTE: here are single quotes important!
# password is 'nots3cr3t'
ROOT_PASSWORD='lQxldvDc9mR/o'

USER_NAME="bernhard"
USER_REAL_NAME="Bernhard"
USER_GROUP_NAME="users"
USER_GID="100"
USER_UID="1000"
USER_HOME="/home/$USER_NAME"

# NOTE: here are single quotes important!
# password is 'nots3cr3t'
USER_PASSWORD='lQxldvDc9mR/o'

THIS_IMAGE="$1"
TEMPLATE="$2"
LINUX32="$3"
shift 3

IMAGE_VERSION=${THIS_IMAGE##*-}
IMAGE_NAME=${THIS_IMAGE%-*}

if [ -d "$IMAGE_PATH/$THIS_IMAGE" ]; then
	rm -rf "$IMAGE_PATH/$THIS_IMAGE"/* &> /dev/null
else
	mkdir "$IMAGE_PATH/$THIS_IMAGE"
fi

cp -R "$SLEPOS_TEMPLATE_PATH/$TEMPLATE"/* "$IMAGE_PATH/$THIS_IMAGE"

sed -i -e "s|<version>[0-9.]*</version>|<version>$IMAGE_VERSION</version>|" "$IMAGE_PATH/$THIS_IMAGE/config.xml"
sed -i -e "s|<image \([^\s]*\)name=['\"][^'\"]*['\"]|<image \1name='$IMAGE_NAME'|" "$IMAGE_PATH/$THIS_IMAGE/config.xml"
sed -i -e "s|displayname=['\"][^'\"]*['\"]|displayname='$IMAGE_NAME'|" "$IMAGE_PATH/$THIS_IMAGE/config.xml"

for s in "$@" ; do
	sed -i -e "$s" "$IMAGE_PATH/$THIS_IMAGE/config.xml"
done

grep -v "wireless support" "$IMAGE_PATH/$THIS_IMAGE/config.xml" |grep -v "SUSE Manager support" > "$IMAGE_PATH/$THIS_IMAGE/config.xml.tmp"
mv -f "$IMAGE_PATH/$THIS_IMAGE/config.xml.tmp" "$IMAGE_PATH/$THIS_IMAGE/config.xml"

# add virtual drivers
for m in drivers/block/virtio_blk.ko  drivers/net/virtio_net.ko  drivers/scsi/virtio_scsi.ko  drivers/virtio/virtio.ko  drivers/virtio/virtio_pci.ko  drivers/virtio/virtio_ring.ko ; do
  sed -i -e "s|</drivers>|<file name='$m'/></drivers>|" "$IMAGE_PATH/$THIS_IMAGE/config.xml"
done

# replace any existing password
sed -i -e "s|pwd=\"[^\"]*\"|pwd=\"$USER_PASSWORD\"|" "$IMAGE_PATH/$THIS_IMAGE/config.xml"

# add users to template
# find good place (after </preferences>)

sed -i "/<\/preferences>/s@\$@\n  <users group=\"$USER_GROUP_NAME\" \>\n    <user home=\"$USER_HOME\" id=\"$USER_UID\" name=\"$USER_NAME\" pwd=\"$USER_PASSWORD\" realname=\"$USER_REAL_NAME\"/>\n  </users>\n@" "$IMAGE_PATH/$THIS_IMAGE/config.xml"

[ -d "$IMAGE_PATH/images/$THIS_IMAGE" ] || mkdir -p "$IMAGE_PATH/images/$THIS_IMAGE"

echo "Updates: $UPDATES"

echo "Step one - prepare image"
${LINUX32} /usr/sbin/kiwi --nocolor --root "$IMAGE_PATH/chroot/$THIS_IMAGE" --prepare "$IMAGE_PATH/$THIS_IMAGE" $UPDATES --logfile "/var/log/image_prepare-$THIS_IMAGE" || \
	{ echo "Step one failed - see log /var/log/image_prepare-$THIS_IMAGE" ; exit 1; }
echo "Step two - create image"
# do not specify "--type pxe " - kiwi should build the default one
${LINUX32} /usr/sbin/kiwi --nocolor --create "$IMAGE_PATH/chroot/$THIS_IMAGE" --destdir "$IMAGE_PATH/images/$THIS_IMAGE" $UPDATES --logfile "/var/log/image_create-$THIS_IMAGE" || \
	{ echo "Step two failed - see log /var/log/image_prepare-$THIS_IMAGE" ; exit 1; }
echo "create_image $THIS_IMAGE succeeded"

