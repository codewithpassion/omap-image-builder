#!/bin/bash
set -e

mkdir -p /boot/uboot

echo "/dev/mmcblk0p2   /           auto   errors=remount-ro   0   1" >> /etc/fstab
echo "/dev/mmcblk0p1   /boot/uboot auto   defaults            0   0" >> /etc/fstab

#Add eth0 to network interfaces, so ssh works on startup.
echo ""  >> /etc/network/interfaces
echo "# The primary network interface" >> /etc/network/interfaces
echo "auto eth0"  >> /etc/network/interfaces
echo "iface eth0 inet dhcp"  >> /etc/network/interfaces
echo "# Example to keep MAC address between reboots"  >> /etc/network/interfaces
echo "#hwaddress ether DE:AD:BE:EF:CA:FE"  >> /etc/network/interfaces
echo "" >> /etc/network/interfaces
echo "# WiFi Example" >> /etc/network/interfaces
echo "#auto wlan0" >> /etc/network/interfaces
echo "#iface wlan0 inet dhcp" >> /etc/network/interfaces
echo "#    wpa-ssid \"essid\"" >> /etc/network/interfaces
echo "#    wpa-psk  \"password\"" >> /etc/network/interfaces

cat > /etc/flash-kernel.conf <<__EOF__
#!/bin/sh
UBOOT_PART=/dev/mmcblk0p1

echo "flash-kernel stopped by: /etc/flash-kernel.conf"
echo "You are currently running an image built by rcn-ee.net running an rcn-ee"
echo "kernel, to use Ubuntu's Kernel remove the next line"
USE_RCN_EE_KERNEL=1

if [ "\${USE_RCN_EE_KERNEL}" ] ; then

DIST=\$(lsb_release -cs)

case "\$DIST" in
    lucid)
            exit 0
        ;;
    maverick|natty|oneiric|precise|quantal)
            FLASH_KERNEL_SKIP=yes
        ;;

esac

fi

__EOF__

cat > /etc/init/board_tweaks.conf <<-__EOF__
	start on runlevel 2

	script
	if [ -f /boot/uboot/SOC.sh ] ; then
	        board=\$(cat /boot/uboot/SOC.sh | grep "board" | awk -F"=" '{print \$2}')
	        case "\${board}" in
	        BEAGLEBONE_A)
	                if [ -f /boot/uboot/tools/target/BeagleBone.sh ] ; then
	                        /bin/sh /boot/uboot/tools/target/BeagleBone.sh &> /dev/null &
	                fi;;
	        esac
	fi
	end script

__EOF__

if which git >/dev/null 2>&1; then
	cd /tmp/
	git clone git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git

	#beaglebone firmware:
	git clone git://arago-project.org/git/projects/am33x-cm3.git
	cd -

	mkdir -p /lib/firmware/ti-connectivity
	cp -v /tmp/linux-firmware/LICENCE.ti-connectivity /lib/firmware/ti-connectivity
	cp -v /tmp/linux-firmware/ti-connectivity/* /lib/firmware/ti-connectivity
	rm -rf /tmp/linux-firmware/

	if [ ! -f /lib/firmware/ti-connectivity/TIInit_7.6.15.bts ] ; then
		wget --directory-prefix=/lib/firmware/ti-connectivity http://rcn-ee.net/firmware/ti/TIInit_7.6.15.bts
	fi

	cp -v /tmp/am33x-cm3/bin/am335x-pm-firmware.bin /lib/firmware/am335x-pm-firmware.bin
	rm -rf /tmp/am33x-cm3/

	#v3.1+ needs 1.9.4 version of the firmware
	rm -f /lib/firmware/carl9170-1.fw || true
	wget --directory-prefix=/lib/firmware/ http://rcn-ee.net/firmware/carl9170/1.9.6/carl9170-1.fw
fi

#just for a bluetooth binary...
cp /etc/apt/sources.list /etc/apt/sources.bak
echo "deb http://ppa.launchpad.net/linaro-maintainers/overlay/ubuntu precise main" >> /etc/apt/sources.list
apt-get update
apt-get -y --force-yes install ti-uim
apt-get clean
rm -f /etc/apt/sources.list || true
mv /etc/apt/sources.bak /etc/apt/sources.list
apt-get update
apt-get clean

####################################
# additions
echo "Setting up additions:"
ADDITIONS=/tmp/additions
if [ -d $ADDITIONS ]; then
        echo "Found additions"
        for item in $ADDITIONS/* ; do
                echo "checking $item"
                if [ -d $item ]; then
                        echo "Found folder: $item"
                        if [ -f $item/install.sh ]; then
                                echo "Executing: $ADDITIONS/$item/install.sh"
                                sh $item/install.sh
                        fi
                fi
        done
fi

####################################

rm -f /tmp/*.deb || true
rm -rf /usr/src/linux-headers* || true
rm -f /rootstock-user-script || true
rm -rf /tmp/additions || true


