

# $1: full path of image file
# $2: size of SD image
disk_create_image ( ) {
    echo "Creating the raw disk image in $1"
    [ -f $1 ] && rm -f $1
    dd if=/dev/zero of=$1 bs=512 seek=$(($2 / 512)) count=0 >/dev/null 2>&1
    _DISK_MD=`mdconfig -a -t vnode -f $1`
}

disk_release_image ( ) {
    mdconfig -d -u ${_DISK_MD}
    unset _DISK_MD
}

# Partition the virtual disk using MBR.
#
# (ROM code for TI AM335X and Raspberry PI both require MBR
# partitioning.)
#
disk_partition_mbr ( ) {
    echo "Partitioning the raw disk image at "`date`
    gpart create -s MBR ${_DISK_MD}
}

# Add a FAT partition and format it.
#
# $1: size of parition, can use 'k', 'm', 'g' suffixes
# TODO: If $1 is empty, use whole disk.
#
disk_fat_create ( ) {
    echo "Creating the FAT partition at "`date`
    gpart add -a 63 -b 63 -s$1 -t '!12' ${_DISK_MD}
    # TODO: we should get _DISK_FAT_PARTITION from gpart
    # (similar to how mdconfig tells us the MD device we used.)
    _DISK_FAT_PARTITION_NUMBER=1
    _DISK_FAT_PARTITION=s${_DISK_FAT_PARTITION_NUMBER}
    _DISK_FAT_DEV=/dev/${_DISK_MD}${_DISK_FAT_PARTITION}
    gpart set -a active -i ${_DISK_FAT_PARTITION_NUMBER} ${_DISK_MD}

    # TODO: Select FAT12, FAT16, or FAT32 depending on partition size
    newfs_msdos -L "boot" -F 12 ${_DISK_FAT_DEV} >/dev/null
}

# $1: Directory where FAT partition will be mounted
disk_fat_mount ( ) {
    echo "Mounting the virtual FAT partition"
    if [ -d "$1" ]; then
	umount "$1"
	rmdir "$1"
    fi
    mkdir "$1"
    mount_msdosfs ${_DISK_FAT_DEV} "$1"
}

# $1: Mount point
disk_fat_unmount ( ) {
    echo "Unmounting FAT partition"
    umount $1
    rmdir $1
}

# TODO: Make this work.
disk_swap_create ( ) {
    #gpart add -s790m -t freebsd -i 3 -f x ${_DISK_MD}
    #_DISK_SWAP_PARTITION=s3
}

# TODO: Support $1 size argument
# TODO: If $1 is empty, use whole disk.
disk_ufs_create ( ) {
    echo "Creating the UFS partition at "`date`

    gpart add -t freebsd -f x ${_DISK_MD}
    _DISK_UFS_PARTITION_NUMBER=2
    _DISK_UFS_PARTITION=s${_DISK_UFS_PARTITION_NUMBER}
    _DISK_UFS_DEV=/dev/${_DISK_MD}${_DISK_UFS_PARTITION}

    newfs ${_DISK_UFS_DEV} >/dev/null
    # Turn on Softupdates
    tunefs -n enable ${_DISK_UFS_DEV}
    # Turn on SUJ with a minimally-sized journal.
    # This makes reboots tolerable if you just pull power on the BB
    # Note:  A slow SDHC reads about 1MB/s, so a 30MB
    # journal can delay boot by 30s.
    tunefs -j enable -S 4194304 ${_DISK_UFS_DEV}
    # Turn on NFSv4 ACLs
    tunefs -N enable ${_DISK_UFS_DEV}
}

# $1: directory where UFS partition will be mounted
disk_ufs_mount ( ) {
    echo "Mounting UFS partition"
    if [ -d $1 ]; then
	umount $1
	rmdir $1
    fi
    mkdir $1
    mount ${_DISK_UFS_DEV} $1
}

disk_ufs_unmount ( ) {
    echo "Unmounting the UFS partition at "`date`
    cd $TOPDIR
    umount ${UFS_MOUNT}
    rmdir ${UFS_MOUNT}
    unset UFS_MOUNT
}