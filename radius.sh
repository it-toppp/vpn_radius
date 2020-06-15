
VPNIP=
RADPASS=
MYPASS=
SITEIP=

yum -y install freeradius freeradius-mysql freeradius-utils mysql mysql-devel mysql-server git
systemctl start mysqld && systemctl enable mysqld

sudo mysql_secure_installation  <<MSI2

y
${MYPASS}
${MYPASS}
y
y
y
y

MSI2

systemctl restart mysqld
mysql -uroot -p$MYPASS -e "CREATE DATABASE radius DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;"
mysql -uroot -p$MYPASS radius < /etc/raddb/mods-config/sql/main/mysql/schema.sql /etc/raddb/mods-config/sql/main/mysql
 
cat > /etc/raddb/clients.conf << HERE
client server-1 {
    	ipaddr      	= $VPNIP
     	secret      	= $RADPASS
     	shortname   	= server-1 
}
HERE

git clone https://github.com/it-toppp/vpn_radius.git
cd vpn_radius
cp -r raddb/* /etc/raddb/mods-available/

cd /etc/raddb/mods-available/
ln -s ../mods-available/inner-eap ../mods-enabled/inner-eap

systemctl restart radiusd

yum -y install firewalld
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" port="3306/tcp" source address="SITEIP/32" accept'
firewall-cmd --permanent --new-ipset=vpnservers --type=hash:ip
firewall-cmd --ipset=vpnservers --add-entry=$VPNIP
firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" port="1812-1813/udp" source ipset=vpnservers accept'
firewall-cmd --reload
