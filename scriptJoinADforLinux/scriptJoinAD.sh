#!/usr/bin/env bash
#This Script is used to join a Linux Server to an Active Directory Domain


#Variables
_hostName=$(hostname)
_domainName="spvn.local"
_fullName=$_hostName.$_domainName
_ipOfAD1=1.1.1.1 #change IP
_ipOfAD2=2.2.2.2  #change IP
_userTOJoin="" #user have perm to join AD
_passwordTOJoin="" #pass of this user to Join AD
_groupPermitLogin="" #Group have full Permission of LinuxMachine

#Set Hostname Remote Machine
sudo hostnamectl set-hostname $_fullName



#configDNS 
sudo apt install resolvconf -y
sudo systemctl enable --now resolvconf
cat <<EOF >> /etc/resolvconf/resolv.conf.d/head
nameserver $_ipOfAD1
nameserver $_ipOfAD2

EOF
sudo systemctl restart resolvconf.service
sudo systemctl restart systemd-resolved.service


#Join AD
echo $_passwordTOJoin | sudo realm join --user=$_userTOJoin $_domainName
sudo realm list | grep $_domainName
if [ $? -eq 0 ]; then
    echo "Join AD Successfully"
#config SSSD
    sudo cat <<EOF > /etc/sssd/sssd.conf
[sssd]
domains = $_domainName
config_file_version = 2
services = nss, pam
default_domain_suffix = $_domainName

[domain/$_domainName]
ad_domain = $_domainName
krb5_realm = ${_domainName^^}
realmd_tags = manages-system joined-with-adcli
cache_credentials = True
id_provider = ad
krb5_store_password_if_offline = True
default_shell = /bin/bash
ldap_id_mapping = True
use_fully_qualified_names = True
fallback_homedir = /home/%u@%d
access_provider = ad
ad_hostname = $_fullName
dydns_update = true
dydns_refresh_interval = 43200
dydns_update_ptr = true
dydns_ttl = 3600
dydns_auth = GSS-TSIG
EOF


#Make Home Directory when new user login
    cat <<EOF > /usr/share/pam-configs/mkhomedir
Name: activate mkhomedir
Default: yes
Priority: 900
Session-Type: Additional
Session:
        required                        pam_mkhomedir.so umask=0022 skel=/etc/skel
EOF

#update pam
    sudo pam-auth-update --enable mkhomedir


#restart sssd
    sudo systemctl restart sssd.service



#permit who can login this server with
    sudo realm permit -g $_groupPermitLogin


#Add group permit login to Sudoer
    sudo cat <<EOF > /etc/sudoers.d/group-permit-login
%$_groupPermitLogin@$_domainName ALL=(ALL) NOPASSWD: ALL
EOF

else
    echo "Join AD Failed"
    exit 1
fi



















