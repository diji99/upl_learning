#!/bin/bash

nfs_server_ip=192.168.0.10
pxe_server_ip=192.168.0.16

umount -f /media
umount -f /var/www/html/dvd
umount -f /mnt

# 1）DHCP：用以分配ip地址

# 2）预启动施行环境（PXE）：通过网卡引导计算机

# 3）PXELINUX：提供引导文件及内核等文件

# 4）kickstart文件：提供安装介质


#第一步:

setenforce 0
echo "/usr/sbin/setenforce 0" >>  /etc/rc.local 
echo "/usr/sbin/iptables -F" >> /etc/rc.local 
#chmod +x /etc/rc.d/rc.local
#source  /etc/rc.local 

route -n 

install_all_software(){
mount -t nfs ${nfs_server_ip}:/content /mnt
yum install -y dhcpd xinetd tftp-server syslinux httpd elinks
}

install_all_software   #install all need software at one time
umount -f /mnt

#第三步:
#设置servera 开启路由功能

echo "/bin/echo 1 > /proc/sys/net/ipv4/ip_forward" >> /etc/rc.local 
cat > /etc/sysctl.conf << EOF
net.ipv4.ip_forward = 1
EOF
sysctl -p

#设置SNAT
#iptables -t nat -A POSTROUTING -s 192.168.0.0/24 -j SNAT --to-source 172.25.0.10

#第四步:  搭建PXE 

# 1)  安装DHCP服务
# serverg ip:192.168.0.16
#ssh serverg
hostnamectl set-hostname pxe
mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.old
cp  /usr/share/doc/dhcp-4.2.5/dhcpd.conf.example /etc/dhcp/dhcpd.conf 

cat > /etc/dhcp/dhcpd.conf <<EOF
allow booting;
allow bootp;

option domain-name "pod0.example.com";
option domain-name-servers 192.168.0.254;
default-lease-time 600;
max-lease-time 7200;
log-facility local7;

subnet 192.168.0.0 netmask 255.255.255.0 {
  range 192.168.0.50 192.168.0.60;
  option domain-name-servers 192.168.0.10;
  option domain-name "pod0.example.com";
  option routers 192.168.0.10;
  option broadcast-address 192.168.0.255;
  default-lease-time 600;
  max-lease-time 7200;
  next-server 192.168.0.16;
  filename "pxelinux.0";
}

class "foo" {
  match if substring (option vendor-class-identifier, 0, 4) = "SUNW";
}

shared-network 224-29 {
  subnet 10.17.224.0 netmask 255.255.255.0 {
    option routers rtr-224.example.org;
  }
  subnet 10.0.29.0 netmask 255.255.255.0 {
    option routers rtr-29.example.org;
  }
  pool {
    allow members of "foo";
    range 10.17.224.10 10.17.224.250;
  }
  pool {
    deny members of "foo";
    range 10.0.29.10 10.0.29.230;
  }
}
EOF

systemctl restart dhcpd

# 2) 配置tftp服务  on pxe server

mv /etc/xinetd.d/tftp /etc/xinetd.d/tftp.bak
cat > /etc/xinetd.d/tftp << EOF
service tftp
{
        socket_type             = dgram
        protocol                = udp
        wait                    = yes
        user                    = root
        server                  = /usr/sbin/in.tftpd
        server_args             = -s /var/lib/tftpboot
        disable                 = no
        per_source              = 11
        cps                     = 100 2
        flags                   = IPv4
}
EOF

service xinetd start
lsof -i:69
chkconfig xinetd on

# configure syslinux包
cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/

# <2> pxelinux.cfg/default
mkdir -p /var/lib/tftpboot/pxelinux.cfg
cd /var/lib/tftpboot/pxelinux.cfg/
touch default

# 定义default菜单文件

cat > /var/lib/tftpboot/pxelinux.cfg/default << EOF

default vesamenu.c32 
timeout 60 
display boot.msg 
menu background splash.png 
menu title Welcome to Global Learning Services Setup! 　

label local  
        menu label Boot from ^local drive 
        menu default　
        localhost 0xffff 

label install 7
        menu label Install  Redhat7
        kernel vmlinuz
        append initrd=initrd.img  ks=http://192.168.0.16/myks.cfg
EOF

# <4> 定义启动的相关文件
# 提供iso到本地，并挂载
#mount -o  loop /mnt/rhel7.1/x86_64/isos/rhel-server-7.1-x86_64-dvd.iso  /media/   ##建议做个NFS
mount -t nfs ${nfs_server_ip}:/content  /media
if [ $? -ne 0 ]; then
   umount -f /media
   mount -t nfs ${nfs_server_ip}:/content  /media
cd /media/isolinux 
cp vesamenu.c32 boot.msg vmlinuz initrd.img /var/lib/tftpboot/
umount  /media
else 
cd /media/isolinux 
cp vesamenu.c32 boot.msg vmlinuz initrd.img /var/lib/tftpboot/
fi
cd /
umount /media

# 3) 通过kickstart工具生成ks文件

cd ~
cat > ks.cfg << EOF
#version=RHEL7
# System authorization information
auth --enableshadow --passalgo=sha512
# Reboot after installation 
reboot # 装完系统之后是否重启
# Use network installation
url --url="http://${pxe_server_ip}/dvd/"  
# Use graphical install
#graphical 
text # 采用字符界面安装
# Firewall configuration
firewall --enabled --service=ssh 
firstboot --disable 
ignoredisk --only-use=vda
# Keyboard layouts
# old format: keyboard us
# new format:
keyboard --vckeymap=us --xlayouts='us'
# System language 
lang en_US.UTF-8 
# Network information
network  --bootproto=dhcp
network  --hostname=server1
#repo --name="Server-ResilientStorage" --baseurl=http://download.eng.bos.redhat.com/rel-eng/latest-RHEL-7/compose/Server/x86_64/os//addons/ResilientStorage
# Root password
rootpw --iscrypted nope 
# SELinux configuration
selinux --disabled
# System services
services --disabled="kdump,rhsmcertd" --enabled="network,sshd,rsyslog,ovirt-guest-agent,chronyd"
# System timezone
timezone Asia/Shanghai --isUtc
# System bootloader configuration
bootloader --append="console=tty0 crashkernel=auto" --location=mbr --timeout=1 --boot-drive=vda 
# 设置boot loader --append --location
# Clear the Master Boot Record
zerombr 
# Partition clearing information
clearpart --all --initlabel
# Disk partitioning information
part / --fstype="xfs" --ondisk=vda --size=6144 
%post # 
echo "redhat" | passwd --stdin root
useradd carol
echo "redhat" | passwd --stdin carol
# workaround anaconda requirements
%end

%packages # 
@core
vim 
ftp 
%end
EOF

# 4) 通过httpd服务发布ks文件
cp ks.cfg /var/www/html/myks.cfg
chown apache. /var/www/html/myks.cfg 
systemctl restart httpd
systemctl enable httpd


#5) 发布iso ---> http://${pxe_server_ip}/dvd/   
mount ${nfs_server_ip}:/content /var/www/html/dvd/
if  [ $? -ne 0 ]; then 
    umount /var/www/html/dvd
    mkdir /var/www/html/dvd
    mount ${nfs_server_ip}:/content /var/www/html/dvd/
    mount ${nfs_server_ip}:/content /var/www/html/dvd/ >> /etc/rc.local
    else
    exit 21
fi

echo "Pxe setup and configure is ok!"
#测试 启动install 虚拟机  

