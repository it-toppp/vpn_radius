  
#!/bin/bash

VPNIP=78.47.147.162
RADPASS=BXdh3DlSi
MYPASS=rerehtre
SITEIP=1.1.1.1

yum -y install freeradius freeradius-mysql freeradius-utils mariadb mariadb-devel mariadb-server git
systemctl start mariadb && systemctl enable mariadb
setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config

sudo mysql_secure_installation 2>/dev/null  <<EOF

y
$MYPASS
$MYPASS
y
y
y
y
EOF

systemctl restart mysqld
mysql -uroot -p$MYPASS -e "CREATE DATABASE radius DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;"
mysql -uroot -p$MYPASS -e "GRANT ALL ON radius.* TO 'radius'@'%' IDENTIFIED BY '$MYPASS';"
mysql -uroot -p$MYPASS radius < /etc/raddb/mods-config/sql/main/mysql/schema.sql
mysql -uroot -p$MYPASS -e "INSERT INTO radius.radcheck (username,attribute,op,value) values ('test7','NT-Password',':=','7A21990FCD3D759941E45C490F143D5F');"
 
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

sed -i 's|newpassword|'$MYPASS'|' /etc/raddb/mods-available/sql

cd /etc/raddb/mods-available/
ln -sf /etc/raddb/mods-available/inner-eap /etc/raddb/mods-enabled/inner-eap
ln -sf /etc/raddb/mods-available/sql /etc/raddb/mods-enabled/sql
ln -s /etc/raddb/sites-available/proxy-inner-tunnel /etc/raddb/sites-enabled/proxy-inner-tunnel

cat > /etc/raddb/sites-enabled/default << HERE
server default {
listen {
    type = auth
    ipaddr = *
    port = 0
    limit {
      	max_connections = 16
      	lifetime = 0
      	idle_timeout = 30
    }
}
listen {
    ipaddr = *
    port = 0
    type = acct
    limit {
    }
}
listen {
    type = auth
    ipv6addr = ::    # any.  ::1 == localhost
    port = 0
    limit {
      	max_connections = 16
      	lifetime = 0
      	idle_timeout = 30
    }
}
listen {
    ipv6addr = ::
    port = 0
    type = acct
    limit {
    }
}
authorize {
    filter_username
    sql
    preprocess
    auth_log
    chap
    mschap
    digest
    suffix
    inner-eap {
   	 ok = return
    }
    files
    sql
    -ldap
    expiration
    logintime
    Autz-Type PAP-SQL {
            	sql
            	pap
    	}
    pap
}
authenticate {
    Auth-Type PAP {
   	 pap
    }
    	Auth-Type md5 {
            	pap
    	}
    Auth-Type CHAP {
   	 chap
    }
    Auth-Type MS-CHAP {
   	 mschap
    }
    mschap
    digest
    inner-eap
}
preacct {
    preprocess
    acct_unique
    suffix
    files
}
accounting {
    detail
    unix
    -sql
    exec
    attr_filter.accounting_response
}
session {
    sql
}
post-auth {
    update {
   	 &reply: += &session-state:
    }
    -sql
    sql
    exec
    remove_reply_message_if_eap
    Post-Auth-Type REJECT {
   	 -sql
   	 attr_filter.access_reject
   	 eap
   	 remove_reply_message_if_eap
    }
    Post-Auth-Type Challenge {
    }
}
pre-proxy {
}
post-proxy {
    eap
}
}
HERE


cat > /etc/raddb/sites-enabled/inner-tunnel << HERE

server inner-tunnel {
listen {
   	ipaddr = 127.0.0.1
   	port = 18120
   	type = auth
}
authorize {
    filter_username
    chap
    mschap
    suffix
    update control {
   	 &Proxy-To-Realm := LOCAL
    }
    inner-eap {
   	 ok = return
    }
    files
    sql
    -ldap
    expiration
    logintime
    
    pap
}
authenticate {
     Auth-Type PAP {
   	 pap
    }
    Auth-Type CHAP {
   	 chap
    }
    Auth-Type MS-CHAP {
   	 mschap
    }
    Auth-Type MS-CHAP2 {
   	 inner-eap
    }
    mschap
    inner-eap
}
session {
    radutmp
    sql
}
post-auth {
    sql
    if (1) {
   	 update reply {
   		 User-Name !* ANY
   		 Message-Authenticator !* ANY
   		 EAP-Message !* ANY
   		 Proxy-State !* ANY
   		 MS-MPPE-Encryption-Types !* ANY
   		 MS-MPPE-Encryption-Policy !* ANY
   		 MS-MPPE-Send-Key !* ANY
   		 MS-MPPE-Recv-Key !* ANY
   	 }
   	 update {
   		 &outer.session-state: += &reply:
   	 }
    }
    Post-Auth-Type REJECT {
   	 sql
   	 attr_filter.access_reject
   	 update outer.session-state {
   		 &Module-Failure-Message := &request:Module-Failure-Message
   	 }
    }
}
pre-proxy {
}
post-proxy {
    inner-eap
}
} # inner-tunnel server block
HERE

#cat > /etc/raddb/sites-enabled/inner-tunnel << HERE
#server proxy-inner-tunnel {
#authorize {
#         update control {
#             &Proxy-To-Realm := "example.com"
#        }
#}
#authenticate {
#        eap
#}
#post-proxy {
#        eap
#}
#}
#HERE

systemctl restart radiusd

yum -y install firewalld
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" port port=3306 protocol=tcp source address="'$SITEIP'/32" accept'
firewall-cmd --permanent --new-ipset=vpn --type=hash:ip
firewall-cmd --reload
firewall-cmd --ipset=vpn --add-entry="$VPNIP" --permanent
firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" port port=1812-1813 protocol=udp source ipset=vpn accept'
firewall-cmd --reload
