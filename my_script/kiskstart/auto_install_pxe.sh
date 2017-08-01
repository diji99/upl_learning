#!/bin/bash 
# 自动在本地生成ssh的密钥对，并自动批量将public key上传到远程主机，实现免密码登录。
keydir=$HOME/.ssh
skey=$keydir/id_rsa
pkey=$keydir/id_rsa.pub
######这个是新系统安装后的root密码，请自行修改。#########
passwd="123456"
############以下txt文件仅仅存储客户端IP（dhcp分配的动态IP范围）#############
ip_file=/shell/rhost.txt
install_file=/shell/kiskstart.sh

# upload pub_key.
for i in $(cat $ip_file)
   do
      expect <<EOF
      spawn  ssh-copy-id  root@$i
      expect {
            "*(yes/no)?"  { send "yes\r";exp_continue }
	    "*password:"  { send "$passwd\r";exp_continue }
	    eof { exit }
	    }
EOF
    scp ${install_file} root@$i:/shell
   # scp ${ip_file} root@$i:/shell
    ssh root@"$i"  /shell/kiskstart.sh &
    echo "Remote install PXE server is Sccessed！"
   done
