##########yum install software###############
mg_server=192.168.5.254
ip_file=/shell/rhost.txt
remote_ip=$(awk '{print $1}' ${ip_file})
rhost=$(ip addr show|grep inet|grep -v inet6|awk -F "[./]" 'NR==2{print $4}')
#rhost=$(awk '{print $1}'${ip_file} |awk -F "." '{print $4}')
inst_soft(){
cat >/etc/yum.repos.d/iso.repo <<EOF
[iso]
name=iso-source
baseurl=http://${mg_server}/pub/rhel7
enabled=1
gpgcheck=0
EOF
yum install -y vim 
yum install -y elinks
yum install -y httpd
}

##############ip routing###################
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

##############ssh_config#############
ssh_config(){
sed -i 's/^#UseDNS/UseDNS/' /etc/ssh/sshd_config
}

#############disable selinux#########
dis_selinux(){
  setenforce 0
  sed -i '/SELINUX=enforcing/c SELINUX=disabled' /etc/selinux/config
}
############shutdown  firewall####################

dis_firewall(){
   systemctl stop firewalld
   systemctl disable firewalld
}

#############set hostname###########
set_hostname(){
   hostname "server"${rhost} 
   echo "server"${rhost} > /etc/hostname
}

ssh-key(){
   ls $HOME/.ssh/id_rsa*
   if  [ $? -ne 0 ];then
        ssh-keygen
        ssh-copy-id root@$rhost 
   fi
}
#################ssh copy & do shell at server location################
ssh_do_rinit(){
   for i in ${remote_ip}
      do
   scp /shell/rinit.sh root@"${i}" ~ 
   ssh root@"${i}" ~ chmod +x rinit.sh
   ssh root@"${i}" ~ rinit.sh & 
      done
}


#host_name=$(cat $rhost_ip |awk '{print $2}') 
#host_ip=$(cat $rhost_ip |awk '{print $1}')
#a["$host_name"] = "$host_ip"


set_hostname
inst_soft
ssh_config
dis_selinux
dis_firewall
#ssh-key
#ssh_do_rinit



