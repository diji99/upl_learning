#/bin/bash

#U盘系统部署:

server_ip=172.25.254.115

fdisk -l /dev/sdb
dd if=/dev/zero of=/dev/sdb bs=500 count=1


fdisk /dev/sdb << EOT
n
p
1

+8G
a
w
EOT


mkfs.ext4 /dev/sdb1

mkdir /mnt/usb
mount /dev/sdb1  /mnt/usb/
df -h |grep mnt


#2> 安装文件系统与BASH程序，重要命令（工具）、基础服务

mkdir -p /dev/shm/usb

cat >/etc/yum.repos.d/iso.repo << EOF
[remote_iso]
name=remote-source
baseurl=http://172.25.254.250/rhel7.2/x86_64/dvd
enabled=1
gpgcheck=0
EOF

yum -y install ftp
yum -y install filesystem  --installroot=/dev/shm/usb/
yum -y install expect coreutils passwd shadow-utils openssh-clients rpm yum net-tools bind-utils vim-enhanced findutils lvm2 util-linux-ng --installroot=/dev/shm/usb/

cp -arv /dev/shm/usb/* /mnt/usb/



#3> 安装内核
mkdir -p /mnt/usb/lib/modules/
mkdir -p /mnt/usb/boot/
cp /boot/vmlinuz-2.6.32-279.el6.x86_64  /mnt/usb/boot/
cp /boot/initramfs-2.6.32-279.el6.x86_64.img  /mnt/usb/boot/
cp -arv /lib/modules/2.6.32-279.el6.x86_64/  /mnt/usb/lib/modules/



#4> 安装GRUB程序
rpm -ivh ftp://172.25.254.250/notes/project/software/grub-0.97-77.el6.x86_64.rpm --root=/mnt/usb/ --nodeps --force


#安装驱动:
grub-install --root-directory=/mnt/usb/  --recheck  /dev/sdb

ls /mnt/usb/boot/grub/

#定义grub.conf
cp /boot/grub/grub.conf /mnt/usb/boot/grub/




#blkid  /dev/sdb1 
#/dev/sdb1: UUID="4019049f-6890-4af7-bac8-ea4bcb729f0d" TYPE="ext4"


cat > /mnt/usb/boot/grub/grub.conf << EOF
default=0
timeout=5
splashimage=/boot/grub/splash.xpm.gz
title  My USB System from uplooking
        root (hd0,0)
        kernel /boot/vmlinuz-2.6.32-358.el6.x86_64 ro root=UUID=4019049f-6890-4af7-bac8-ea4bcb729f0d selinux=0
        initrd /boot/initramfs-2.6.32-358.el6.x86_64.img
EOF
                                                     


#完善环境变量与配置文件:
mkdir /mnt/usb/root/
cp  /etc/skel/.bash* /mnt/usb/root/
chroot /mnt/usb/
exit
exit
ssh ${server_ip}

网络：
mkdir -p /mnt/usb/etc/sysconfig/network-scripts
cat > /mnt/usb/etc/sysconfig/network-scripts/network << EOF
NETWORKING=yes
HOSTNAME=usb.hugo.org
EOF
cp /etc/sysconfig/network-scripts/ifcfg-eth0 /mnt/usb/etc/sysconfig/network-scripts/
cat > /mnt/usb/etc/sysconfig/network-scripts/ifcfg-eth0 << EOF
DEVICE=eth0
BOOTPROTO=none
ONBOOT=yes
USERCTL=no
IPADDR=192.168.0.123
NETMASK=255.255.255.0
GATEWAY=192.168.0.254
EOF

cat > /mnt/usb/etc/fstab << EOF
UUID="4019049f-6890-4af7-bac8-ea4bcb729f0d" / ext4 defaults 0 0
sysfs                   /sys                    sysfs   defaults        0 0
proc                    /proc                   proc    defaults        0 0
tmpfs                   /dev/shm                tmpfs   defaults        0 0
devpts                  /dev/pts                devpts  gid=5,mode=620  0 0
EOF

grub-md5-crypt  << EOT
redhat
redhat
EOT


sed -i 'root:*/c/root.$1$qKIrQ/$dUdFiJ49LW70wmYqz2pcF/' /mnt/usb/etc/shadow

#同步脏数据
sync
reboot

#选择从U盘启动












