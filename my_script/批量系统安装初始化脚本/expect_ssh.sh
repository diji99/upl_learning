#!/bin/bash 
# 自动在本地生成ssh的密钥对，并自动批量将public key上传到远程主机，实现免密码登录。
keydir=$HOME/.ssh
skey=$keydir/id_rsa
pkey=$keydir/id_rsa.pub
######这个是新系统安装后的root密码，请自行修改。#########
passwd="redhat"
ip_file=/shell/rhost.txt
rinit_file=/shell/init.sh
rinit_setup_script=/shell/set_ip_hostname.sh
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
    scp ${rinit_file} root@$i:~ 
    ssh root@"$i"  ~/init.sh &
    scp ${rinit_setup_script} root@$i:~
    ssh root@"$i"  ~/set_ip_hostname.sh &
    echo "Remote init is sccessed！"
   done


