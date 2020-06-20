#!/bin/bash
echo -n "Please set VPN_SERVER_NAME and press [ENTER]. Example: node1.ultavpn.com:  "
read VPNNOD
echo -n "Please set IP_RADIUS_SERVER and press [ENTER]:  "
read RADSRV
echo -n "Please set PASSWORD_RADIUS_SERVER and press [ENTER]:  "
read RADPASS
VPNIP=$(curl ifconfig.me)
#DIG_IP=$(getent ahostsv4 $SYNAPSE_DOMAIN | sed -n 's/ *STREAM.*//p')
#(getent hosts $SYNAPSE_DOMAIN | awk '{ print $1 }')

setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config

# Ставим radiusclient (нужен для xl2tpd и pptpd):
yum install -y epel-release  gcc mc make wget tar unzip freeradius-utils pam-devel git
wget  https://github.com/FreeRADIUS/freeradius-client/archive/master.tar.gz
tar zxvf master.tar.gz && cd freeradius-client-master
./configure --prefix=/
make
make install
 
#RADIUS_SRV
cat > /etc/radiusclient/servers << HERE
$RADSRV        $RADPASS
HERE

#L2TP:
yum -y install xl2tpd pptpd
modprobe nf_conntrack_proto_gre
modprobe nf_conntrack_pptp
yum -y install ftp://ftp.pbone.net/mirror/archive.fedoraproject.org/epel/8.1.2020-04-22/Everything/x86_64/Packages/s/strongswan-5.7.2-1.el8.x86_64.rpm
 
cat > /etc/xl2tpd/xl2tpd.conf << HERE
[global]
port = 1701
access control = no
ipsec saref = yes
force userspace = yes
auth file = /etc/ppp/chap-secrets
[lns default]
ip range = 10.1.0.0-10.1.255.255
local ip = 10.1.0.1
require authentication = yes
name = ultavpn
pass peer = yes
ppp debug = no
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
require pap = yes
HERE

cat > /etc/ppp/options.xl2tpd << HERE
ipcp-accept-local
ipcp-accept-remote
ms-dns  8.8.8.8
ms-dns  1.1.1.1
ms-dns  10.1.0.1
noccp
auth
crtscts
idle 1800
mtu 1460
mru 1460
nodefaultroute
#debug
lock
proxyarp
connect-delay 5000
plugin radius.so
plugin radattr.so
HERE

cat >  /etc/strongswan/ipsec.secrets << HERE
: RSA "/etc/strongswan/ipsec.d/certs/privkey.pem"
%any %any : PSK "yDASt9wM4r8gYy4VODnm0Tvb”
HERE

cat > /etc/pptpd.conf << HERE
option /etc/ppp/options.pptpd
logwtmp
connections 1024
localip 10.3.0.1
remoteip 10.3.0.0-255,10.3.1.0-255,10.3.2.0-255,10.3.3.0-255
HERE

cat > /etc/ppp/options.pptpd << HERE
name pptpd
refuse-chap
refuse-mschap
require-pap
ms-dns 8.8.8.8
ms-dns 1.1.1.1
proxyarp
lock
nobsdcomp
novj
novjccomp
nologfd
plugin radius.so
plugin radattr.so
HERE

cat > /etc/radiusclient/radiusclient.conf << HERE
auth_order  radius,local
login_tries 4
login_timeout       60
nologin /etc/nologin
issue       /etc/radiusclient/issue
authserver  $RADSRV
acctserver  $RADSRV
servers             /etc/radiusclient/servers
dictionary  /etc/radiusclient/dictionary
login_radius /usr/sbin/login.radius
mapfile             /etc/radiusclient/port-id-map
seqfile /var/run/radius.seq
default_realm
radius_timeout      10
radius_retries      3
radius_deadtime     0
bindaddr *
login_local /bin/login
HERE

cat > /etc/radiusclient/dictionary.microsoft << HERE
VENDOR           Microsoft                       311
ATTRIBUTE        MS-CHAP-Response                        1       string  Microsoft
ATTRIBUTE        MS-CHAP-Error                           2       string  Microsoft
ATTRIBUTE        MS-CHAP-CPW-1                           3       string  Microsoft
ATTRIBUTE        MS-CHAP-CPW-2                           4       string  Microsoft
ATTRIBUTE        MS-CHAP-LM-Enc-PW                       5       string  Microsoft
ATTRIBUTE        MS-CHAP-NT-Enc-PW                       6       string  Microsoft
ATTRIBUTE        MS-MPPE-Encryption-Policy               7       string  Microsoft
ATTRIBUTE        MS-MPPE-Encryption-Type                 8       string  Microsoft
ATTRIBUTE        MS-MPPE-Encryption-Types                8       string  Microsoft
ATTRIBUTE        MS-RAS-Vendor                           9       integer Microsoft
ATTRIBUTE        MS-CHAP-Domain                          10      string  Microsoft
ATTRIBUTE        MS-CHAP-Challenge                       11      string  Microsoft
ATTRIBUTE        MS-CHAP-MPPE-Keys                       12      string  Microsoft
ATTRIBUTE        MS-BAP-Usage                            13      integer Microsoft
ATTRIBUTE        MS-Link-Utilization-Threshold           14      integer Microsoft
ATTRIBUTE        MS-Link-Drop-Time-Limit                 15      integer Microsoft
ATTRIBUTE        MS-MPPE-Send-Key                        16      string  Microsoft
ATTRIBUTE        MS-MPPE-Recv-Key                        17      string  Microsoft
ATTRIBUTE        MS-RAS-Version                          18      string  Microsoft
ATTRIBUTE        MS-Old-ARAP-Password                    19      string  Microsoft
ATTRIBUTE        MS-New-ARAP-Password                    20      string  Microsoft
ATTRIBUTE        MS-ARAP-PW-Change-Reason                21      integer Microsoft
ATTRIBUTE        MS-Filter                               22      string  Microsoft
ATTRIBUTE        MS-Acct-Auth-Type                       23      integer Microsoft
ATTRIBUTE        MS-Acct-EAP-Type                        24      integer Microsoft
ATTRIBUTE        MS-CHAP2-Response                       25      string  Microsoft
ATTRIBUTE        MS-CHAP2-Success                        26      string  Microsoft
ATTRIBUTE        MS-CHAP2-CPW                            27      string  Microsoft
ATTRIBUTE        MS-Primary-DNS-Server                   28      ipaddr  Microsoft
ATTRIBUTE        MS-Secondary-DNS-Server                 29      ipaddr  Microsoft
ATTRIBUTE        MS-Primary-NBNS-Server                  30      ipaddr  Microsoft
ATTRIBUTE        MS-Secondary-NBNS-Server                31      ipaddr  Microsoft
VALUE    MS-BAP-Usage                    Not-Allowed             0
VALUE    MS-BAP-Usage                    Allowed                 1
VALUE    MS-BAP-Usage                    Required                2
VALUE    MS-ARAP-PW-Change-Reason        Just-Change-Password    1
VALUE    MS-ARAP-PW-Change-Reason        Expired-Password        2
VALUE    MS-ARAP-PW-Change-Reason        Admin-Requires-Password-Change 3
VALUE    MS-ARAP-PW-Change-Reason        Password-Too-Short      4
VALUE    MS-Acct-Auth-Type               PAP                     1
VALUE    MS-Acct-Auth-Type               CHAP                    2
VALUE    MS-Acct-Auth-Type               MS-CHAP-1               3
VALUE    MS-Acct-Auth-Type               MS-CHAP-2               4
VALUE    MS-Acct-Auth-Type               EAP                     5
VALUE    MS-Acct-EAP-Type                MD5                     4
VALUE    MS-Acct-EAP-Type                OTP                     5
VALUE    MS-Acct-EAP-Type                Generic-Token-Card      6
VALUE    MS-Acct-EAP-Type                TLS                     13
HERE

sed -i 's|.*Framed-IPv6-Prefix.*|#|' /etc/radiusclient/dictionary
sed -i 's|.*Framed-IPv6-Address.*|#|' /etc/radiusclient/dictionary
sed -i 's|.*DNS-Server-IPv6-Address.*|#|' /etc/radiusclient/dictionary
sed -i 's|.*Route-IPv6-Information.*|#|' /etc/radiusclient/dictionary
echo "INCLUDE /etc/radiusclient/dictionary.microsoft" >> /etc/radiusclient/dictionary


cat >  /etc/strongswan/ipsec.conf << HERE
config setup
        strictcrlpolicy=yes
        uniqueids = never
        nat_traversal=yes
        virtual_private=%v4:10.1.0.0/16
        oe=off
        protostack=netkey

conn ultavpn
  auto=add
  compress=no
  type=tunnel
  keyexchange=ikev2
  fragmentation=yes
  forceencaps=yes
  ike=aes128-sha1-modp1024,aes128-sha1-modp1536,aes128-sha1-modp2048,aes128-sha256-ecp256,aes128-sha256-modp1024,aes128-sha256-modp1536,aes128-sha256-modp2048,aes256-aes128-sha256-sha1-modp2048-modp4096-modp1024,aes256-sha1-modp1024,aes256-sha256-modp1024,aes256-sha256-modp1536,aes256-sha256-modp2048,aes256-sha256-modp4096,aes256-sha384-ecp384,aes256-sha384-modp1024,aes256-sha384-modp1536,aes256-sha384-modp2048,aes256-sha384-modp4096,aes256gcm16-aes256gcm12-aes128gcm16-aes128gcm12-sha256-sha1-modp2048-modp4096-modp1024,3des-sha1-modp1024!
  esp=aes128-aes256-sha1-sha256-modp2048-modp4096-modp1024,aes128-sha1,aes128-sha1-modp1024,aes128-sha1-modp1536,aes128-sha1-modp2048,aes128-sha256,aes128-sha256-ecp256,aes128-sha256-modp1024,aes128-sha256-modp1536,aes128-sha256-modp2048,aes128gcm12-aes128gcm16-aes256gcm12-aes256gcm16-modp2048-modp4096-modp1024,aes128gcm16,aes128gcm16-ecp256,aes256-sha1,aes256-sha256,aes256-sha256-modp1024,aes256-sha256-modp1536,aes256-sha256-modp2048,aes256-sha256-modp4096,aes256-sha384,aes256-sha384-ecp384,aes256-sha384-modp1024,aes256-sha384-modp1536,aes256-sha384-modp2048,aes256-sha384-modp4096,aes256gcm16,aes256gcm16-ecp384,3des-sha1!
  dpdaction=clear
  dpddelay=180s
  rekey=no
  left=%any
  leftid=@$VPNNOD
  leftsubnet=0.0.0.0/0
#  leftauth=psk
#  leftauth=eap
  leftcert=/etc/strongswan/ipsec.d/certs/fullchain.pem
  leftsendcert=always
  right=%any
  rightid=%any
  rightauth=eap-radius
#  rightauth=xauth-pam
#  rightauth=eap-mschapv2
#  rightauth=xauth-pam
  rightdns=8.8.8.8,1.1.1.1
  rightsourceip=10.2.0.0/16
  rightsendcert=never
#  authby=secret
  eap_identity=%any

conn L2TP-PSK-NAT
    rightsubnet=vhost:%priv
    also=L2TP-PSK-noNAT

conn L2TP-PSK-noNAT
    authby=secret
    pfs=no
    auto=add
    keyingtries=3
    rekey=no
    ikelifetime=8h
    keylife=1h
    type=transport
    left=%any
    leftprotoport=udp/1701
    right=%any
    rightprotoport=udp/%any
    ike=aes128-sha1-modp1536,aes128-sha1-modp1024,aes128-md5-modp1536,aes128-md5-modp1024,3des-sha1-modp1536,3des-sha1-modp1024,3des-md5-modp1536,3des-md5-modp1024
    esp=aes128-sha1-modp1536,aes128-sha1-modp1024,aes128-md5-modp1536,aes128-md5-modp1024,3des-sha1-modp1536,3des-sha1-modp1024,3des-md5-modp1536,3des-md5-modp1024
HERE

cat /etc/strongswan/strongswan.conf << HERE

charon {
        load = charon acert attr ccm chapoly cmac constraints counters ctr des dhcp dnskey duplicheck eap-aka eap-aka-3gpp eap-aka-3gpp2 eap-dynamic eap-gtc eap-md5 eap-mschapv2 eap-peap eap-sim eap-tls eap-ttls farp fips-prf gcm gcrypt led md4 mgf1 openssl pgp pkcs11 pkcs12 pkcs7 pkcs8 pubkey random rc2 resolve sshkey stroke tpm unity xauth-eap xauth-generic xauth-noauth xauth-pam xcbc nonce aes sha1 sha2 md5 pem pkcs1 curve25519 gmp x509 curl revocation hmac vici kernel-netlink socket-default eap-identity eap-radius updown
        include /etc/strongswan/strongswan.d/charon/*.conf
        include /etc/strongswan/strongswan.d/*.conf
        plugins {
                        include strongswan.d/charon/*.conf
        }
}
include /etc/strongswan/strongswan.d/charon/*.conf
include /etc/strongswan/strongswan.d/*.conf
HERE

cat > /etc/strongswan/strongswan.d/charon/eap-radius.conf << HERE
eap-radius {
    accounting = yes
    load = yes
    port = 1812
    dae {
    }
    forward {
    }
    servers {
                main {
                        preference = 99
                        address = $RADSRV
                        auth_port = 1812
                        secret = $RADPASS
                        sockets = 5
                }
    }
    xauth {
    }
}
HERE

cat > /etc/strongswan/strongswan.d/charon/openssl.conf << HERE
openssl {

    # ENGINE ID to use in the OpenSSL plugin.
    # engine_id = pkcs11

    # Set OpenSSL FIPS mode: disabled(0), enabled(1), Suite B enabled(2).
    fips_mode = 0

    # Whether to load the plugin. Can also be an integer to increase the
    # priority of this plugin.
    load = yes

}
HERE

yum -y install firewalld
systemctl start firewalld && systemctl enable firewalld
yum -y install certbot
firewall-cmd --add-service=http --permanent 
firewall-cmd --add-service=https --permanent 
firewall-cmd --reload

certbot certonly --rsa-key-size 4096 --standalone --agree-tos --no-eff-email --email admin@$VPNNOD -d $VPNNOD
rm -fd /etc/strongswan/ipsec.d/certs
ln -sf /etc/letsencrypt/live/$VPNNOD /etc/strongswan/ipsec.d/certs 
ln -sf /etc/letsencrypt/live/$VPNNOD/privkey.pem /etc/strongswan/ipsec.d/private/privkey.pem
ln -sf /etc/letsencrypt/live/$VPNNOD/chain.pem /etc/strongswan/ipsec.d/cacerts/chain.pem
#ln -sf /etc/letsencrypt/live/$VPNNOD/ /etc/strongswan/ipsec.d/reqs 

systemctl enable xl2tpd && systemctl start xl2tpd
systemctl enable strongswan &&	systemctl start strongswan
systemctl enable pptpd &&	systemctl start pptpd
 
#SOCKS:
#wget -O 3proxy-devel.zip --no-check-certificate https://github.com/z3APA3A/3proxy/archive/devel.zip
#unzip 3proxy-devel.zip && cd 3proxy-devel
git clone https://github.com/iamwind/3proxy.git && cd 3proxy
make -f Makefile.Linux
make -f Makefile.Linux install
/usr/bin/cp bin/3proxy /bin/

cat >  /etc/init.d/3proxy  << HERE
#!/bin/sh
### BEGIN INIT INFO
# Provides:          3proxy
# Required-Start:
# Required-Stop:
# Should-Start:
# Should-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start/stop 3proxy
# Description:       Start/stop 3proxy, tiny proxy server
### END INIT INFO
# chkconfig: 2345 20 80
# description: 3proxy tiny proxy server

case "\$1" in
   start)
       echo Starting 3Proxy
       /bin/mkdir -p /var/run/3proxy
       /bin/3proxy /etc/3proxy/3proxy.cfg
       RETVAL=\$?
       echo
       [ \$RETVAL ]
       ;;
   stop)
       echo Stopping 3Proxy
       if [ -f /var/run/3proxy/3proxy.pid ]; then
               /bin/kill \`cat /var/run/3proxy/3proxy.pid\`
       else
               /usr/bin/killall 3proxy
       fi
       RETVAL=\$?
       echo
       [ \$RETVAL ]
       ;;
   restart|reload)
       echo Reloading 3Proxy
       if [ -f /var/run/3proxy/3proxy.pid ]; then
               /bin/kill -s USR1 \`cat /var/run/3proxy/3proxy.pid\`
       else
               /usr/bin/killall -s USR1 3proxy
       fi
       ;;
   *)
       echo Usage: \$0 "{start|stop|restart}"
       exit 1
esac
exit 0
HERE

#cd /etc/3proxy/
#ln -sf /usr/local/3proxy/conf /etc/3proxy/conf
 
cat > /usr/local/3proxy/conf/3proxy.cfg << HERE
nscache 65536
nserver 8.8.8.8
nserver 1.1.1.1
config /conf/3proxy.cfg
monitor /conf/3proxy.cfg
log /logs/3proxy-%y%m%d.log D
rotate 60
counter /count/3proxy.3cf
users passwd
include /conf/counters
include /conf/bandlimiters
external $VPNIP
internal $VPNIP
#auth strong
radius $RADPASS $RADSRV
auth radius
proxy -p3128
socks -p1080
deny * * 127.0.0.1,10.0.0.0/8
allow *
proxy -n
socks
flush
#allow admin
#admin -p8080
HERE
 
cat > /etc/systemd/system/3proxy.service << HERE
[Unit]
Description=3proxy Proxy Server
After=syslog.target network.target
 
[Service]
Type=forking
ExecStart=/etc/init.d/3proxy start
 
[Install]
WantedBy=multi-user.target

HERE

systemctl start 3proxy && systemctl enable 3proxy

#OpenVPN:
 
yum -y install openvpn easy-rsa chrony
 
cd /usr/share/easy-rsa/3
cat > /usr/share/easy-rsa/3/vars  << HERE
export KEY_COUNTRY="NL"
export KEY_PROVINCE="Amsterdam"
export KEY_CITY="Amsterdam"  export KEY_ORG="ULTAVPN"
export KEY_EMAIL="info@ultavpn.com"
export KEY_CN="ULTAVPN"
export KEY_OU="ULTAVPN"
export KEY_NAME="client.ultavpn.com"
export KEY_ALTNAMES="vpn-server"
HERE

. ./vars
./easyrsa init-pki
./easyrsa gen-dh
#./easyrsa build-ca
#./easyrsa gen-req vpn-server nopass
#./easyrsa sign-req server vpn-server
#openvpn --genkey --secret pki/ta.key
 
#cp -r pki/* /etc/openvpn/
 
cp -r /usr/share/easy-rsa/3/pki/dh.pem /etc/openvpn/dh.pem
cat > /etc/openvpn/ca.crt << HERE
-----BEGIN CERTIFICATE-----
MIIDMDCCAhigAwIBAgIUY+kFJtsaNkfBOLnOlTDrQAL4XuQwDQYJKoZIhvcNAQEL
BQAwDTELMAkGA1UEAwwCY2EwHhcNMjAwNjAzMDkxMjMzWhcNMzAwNjAxMDkxMjMz
WjANMQswCQYDVQQDDAJjYTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
AMP7wIowX0FdjabvIm+jeBU3gdMiSnFcTY0lTlvVjagafAIxCHZmssRq3sttiHh+
j8ZcCg5myBhLwCICAJ2MthrpDtzvM4C3/JiTkzGjssnL2e5FV5VaPvuKWT/ZmVb5
Aq1Fdhsj88y+HQVxfeGFWo+yXebTc0/aUgE296LwgFp3tpAI3Vf1AnCfhPN1JBNG
RZic0dSmjj2psmMf+kaucISyYhrQUNFTsSXf5fy1Ak1gDLQMIpAnsT+webfByftZ
YYUy92G7+MfAFhf1UCMF0WsTu1ms8e8PLxMRBSeqwM75xCYQatIGyeiqYlTPlJ8n
4E3ziY1dqAEevMOA7dzr97MCAwEAAaOBhzCBhDAdBgNVHQ4EFgQUPjSqfGmn67bd
L5/7twL7J7KE2yowSAYDVR0jBEEwP4AUPjSqfGmn67bdL5/7twL7J7KE2yqhEaQP
MA0xCzAJBgNVBAMMAmNhghRj6QUm2xo2R8E4uc6VMOtAAvhe5DAMBgNVHRMEBTAD
AQH/MAsGA1UdDwQEAwIBBjANBgkqhkiG9w0BAQsFAAOCAQEAtr1DGoOIAM4B9qnG
807AwG+LxCleJ4wBqcPrJglQEPiSpjTfKMP5XVkpQlYyVh85xfPOQQrTs7xpb2JS
hm7ILgy/qtuP0jt2KRRK5o86/cQ6CIymxTZBAJYgD6ocb5BU4B5/YAI85vaE1evI
fmHwlgppYUWBVOul8qcKRi9gp9uTXjw8558mIQIndeIfGGA36hWz+fNsw1BIudfL
YaiiO7QeUhZwmpdA7MXv9nfC73Al5vfk3/pN23OIderUQun1WKi5a/M6lRUa4vOJ
wnJa3QF5dBbAL2xjs9wKLBYZ8BfGHngycbOSCpj4+JRCgHakXLJsmSba3m5lfg86
zMrxdQ==
-----END CERTIFICATE-----
HERE

cat > /etc/openvpn/vpn-server.crt << HERE
-----BEGIN CERTIFICATE-----
MIIDTzCCAjegAwIBAgIQZ8r1uyJQdBllVc1T9II71TANBgkqhkiG9w0BAQsFADAN
MQswCQYDVQQDDAJjYTAeFw0yMDA2MDMwOTE3NTNaFw0yMjA5MDYwOTE3NTNaMA4x
DDAKBgNVBAMMA2NsMTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANfU
P4kuoiAgkahHepfYA+Pc3NktwTKbxU7uDDwC4ZnhhgqK9sp+SDAdutbrZ4CGsnkC
6ZomGnrzkYsvnmaRBGjPwWCGY/jwJas6e/7AHx2Zj+vT0FykRojJNK80qR8ZFCpI
ki+1MQ7DfehLl+JJYQkpGUAWnBrEYhTOzJRpwmUhydhPymsrIUgXkiGGG82j+5h8
nkOdm9RkykNHxxXBtX9mv8bOKQLbSw7MWQzbyP/vAoJV6LJjq2EHXXhe2+wj4gqH
RLRpTKAKQ67bjgxBmI2NhpQ3HgrEskf3bqQx60kUDh9HoCLx6p89A+pnqiiBYpyn
8+1lGxb/+jWHH+zq31ECAwEAAaOBqTCBpjAJBgNVHRMEAjAAMB0GA1UdDgQWBBRo
8dlXTx/gK7w1zh95+6WpAzwYSDBIBgNVHSMEQTA/gBQ+NKp8aafrtt0vn/u3Avsn
soTbKqERpA8wDTELMAkGA1UEAwwCY2GCFGPpBSbbGjZHwTi5zpUw60AC+F7kMBMG
A1UdJQQMMAoGCCsGAQUFBwMBMAsGA1UdDwQEAwIFoDAOBgNVHREEBzAFggNjbDEw
DQYJKoZIhvcNAQELBQADggEBAArYgpv4M4L/GXJCx03qatmRlzxulT4y4Lz0lfHS
CTD155f4ASGCPMw5TokriOgRGqnY5EmXpM6ck3qCvE0zrnSYDZCFMERoxRnEb78H
IZ0NkO6YevVGh+Uh3GbgRWylw0RZ/g1+9er5tQCnzjD0iE1YKCsaTVFTYVpUk2nT
1e2rBhTNIVSalw8xZPqHhJaGwLoBTxEV7Iua7/zTZzhyOrJLtnkMipFYptsJFx49
GpZnpnxxiS18MV7YlFLkzqVX0Bt94AnZodinlRPgQRkG6tu1+8exNPLolgFbgc3s
XuEiDHCIIwj//xt7e2fNy/gJHCzg2oBII6SpkYmvfJhffg0=
-----END CERTIFICATE-----
HERE

cat > /etc/openvpn/vpn-server.key << HERE
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDX1D+JLqIgIJGo
R3qX2APj3NzZLcEym8VO7gw8AuGZ4YYKivbKfkgwHbrW62eAhrJ5AumaJhp685GL
L55mkQRoz8FghmP48CWrOnv+wB8dmY/r09BcpEaIyTSvNKkfGRQqSJIvtTEOw33o
S5fiSWEJKRlAFpwaxGIUzsyUacJlIcnYT8prKyFIF5IhhhvNo/uYfJ5DnZvUZMpD
R8cVwbV/Zr/GzikC20sOzFkM28j/7wKCVeiyY6thB114XtvsI+IKh0S0aUygCkOu
244MQZiNjYaUNx4KxLJH926kMetJFA4fR6Ai8eqfPQPqZ6oogWKcp/PtZRsW//o1
hx/s6t9RAgMBAAECggEBAMDPMS9pRJa04crWiFNsPBVs8rLl6ClA9WRMzwsxe79P
tMJoYI6HgA/UD1z+kclFC92FV5FJJvDd9RDFqplwReMoblW/2UHDr7MnHSx5D5MO
437HC+YnL4f1T6aRweAxNE2N5WLPWJMa27kRBw+1hAV9/Lu/NxfGhuSV1jdjv7E9
eMxHmwbdIukK0W251tsvFhrXHnGVwmhLTzxQKcBgS08CBa1iV5FgmvJ23AqF02kr
pJRUMTE4e6R0AZRaUsrStNdDGVkKBlalxKN9rlCkaPttSU+Al/Hh6z8Npog3j/tv
kFAolXt5eRquALosAYfMNtpUbviDl0gUwEog90uinAECgYEA9TJ+TqEzet1WgwM2
bwfCBwY0zPSA+hb7EVRxw+pulqUrIIIkMaPuOTxHPRVO3iZ00IWEqsPa0+JDB51J
mYMPZDw3UH4kH1xiGfzn+2rkKFXCmlUGsc+go3NBFq1PwxYPAiGROkuENUSWArMN
M9790P7AiNJaeCLMmBUgS6+/j0ECgYEA4VaFLl3NgiQ524qvEGNwbe+2WsU1lOXA
RBzwP1eMa3wL7ptA6VcrGyPUFqgzyHszTvkuLaWF5TC35lGvRfb3oBLiDA8urIrE
bQJtS/xk4LGjGmZrjiWX7zjJk2+jztHk5YOH1yW0y33fcaSBssPMRdeo6VC3cfg4
DTQNArL3XBECgYAN0/srlAvDMhhe6x92w4k9vCveIyvi7sjaAVkpI195P3dfLfe8
lPIqaCvcVgdMn/6Wg/EncEQ3DtuY4lX0Ql/r1zmHYJXI7vzZWln649xaKfv/mCv4
ey0kCqvxC3UkG2pdRGdcUkXyexu6qz5jXoAR+UwCa1qOy+ed7BMWMaMsAQKBgHBP
RyHM7timZY/el1J7vVWN3D1xfTsxJ5rLMZLgd8Q6l1fdWYTzRTDJsrN4MhcCEJiT
6Ugm741DsuTAYbNlXBYUU0Xfa0vj/fK2+vKcYUr8PmayFXlLk2ZPz2gEhIhYZNVf
sRyyVmH14qApdds7a1yEGFPxPv020fkCsFlgCZmBAoGBALiAkKutcAm7Vu5StiR9
HbQiYJIQawrdgzkFh2OC3uaF1FsN1nR51EcM4jxfWkh/RaOdB4+IqsIbHb/SaP+u
ygTSoxdp6ExukMpTIJiETtxm6Fz6uUl+OlPWBhUIDkIiOWOnl0aaMF1VI9d9EzHv
Lj0U1EWqlmePlpDY5H1/CoSP
-----END PRIVATE KEY-----
HERE

mkdir /var/log/openvpn/
cat >  /etc/openvpn/server.conf << HERE
plugin /usr/lib64/openvpn/plugins/openvpn-plugin-auth-pam.so openvpn
port 1194
proto udp
dev tun21

ca /etc/openvpn/ca.crt
cert /etc/openvpn/vpn-server.crt
key /etc/openvpn/vpn-server.key
dh /etc/openvpn/dh.pem

server 10.0.0.0 255.255.0.0
push "redirect-gateway def1"
push "remote-gateway 10.0.0.1"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 1.1.1.1"

keepalive 10 120
max-clients 1032
status /var/log/openvpn/openvpn-status.log
log /var/log/openvpn/openvpn.log
log-append  /var/log/openvpn/openvpn1.log
verb 6
mute 20
explicit-exit-notify 1
daemon
mode server
verify-client-cert none
HERE
 
cat > /etc/openvpn/tcp.conf << HERE
plugin /usr/lib64/openvpn/plugins/openvpn-plugin-auth-pam.so openvpn
port 1194
proto tcp
dev tun12
ca /etc/openvpn/ca.crt
cert /etc/openvpn/vpn-server.crt
key /etc/openvpn/vpn-server.key
dh /etc/openvpn/dh.pem

server 10.4.0.0 255.255.0.0
#ifconfig-pool-persist ipp.txt
push "redirect-gateway def1"
push "remote-gateway 10.4.0.1"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 1.1.1.1"

duplicate-cn
keepalive 10 120
max-clients 1032
persist-key
persist-tun
status /var/log/openvpn/openvpn-status.log
log /var/log/openvpn/openvpn.log
verb 3
mute 20
daemon
mode server
verify-client-cert none
HERE

ln -sf /usr/sbin/openvpn /etc/init.d/openvpn.udp
ln -sf /usr/sbin/openvpn /etc/init.d/openvpn.tcp
 
cat > /etc/systemd/system/openvpn-tcp.service << HERE
[Unit]
Description=OpenVPN TCP
After=network.target
 
[Service]
Type=forking
ExecStart=/etc/init.d/openvpn.tcp /etc/openvpn/tcp.conf 
 
[Install]
WantedBy=multi-user.target
HERE

cat > /etc/systemd/system/openvpn-udp.service << HERE
[Unit]
Description=OpenVPN UDP
After=network.target
 
[Service]
Type=forking
ExecStart=/etc/init.d/openvpn.udp /etc/openvpn/server.conf
 
[Install]
WantedBy=multi-user.target
HERE


cat > /etc/pam.d/openvpn << HERE
auth	 required    	pam_radius_auth.so
account  required    	pam_radius_auth.so
HERE

cat >/etc/pam_radius.conf << HERE
# server[:port] shared_secret  	timeout (s)
$RADSRV $RADPASS        	3
HERE
 
systemctl enable openvpn-udp && systemctl start openvpn-udp 
systemctl enable openvpn-tcp && systemctl start openvpn-tcp 

cat > /etc/sysctl.conf << HERE
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
HERE
sysctl -p /etc/sysctl.conf

#firewalld:
 
cat > /etc/firewalld/direct.xml << HERE
<?xml version="1.0" encoding="utf-8"?>
<direct>
  <rule ipv="ipv4" table="nat" chain="POSTROUTING" priority="0">-o eth0 -j MASQUERADE</rule>
  <rule ipv="ipv4" table="filter" chain="FORWARD" priority="0">-i ppp0 -o eth0 -j ACCEPT</rule>
  <rule ipv="ipv4" table="filter" chain="FORWARD" priority="0">-i eth0 -o ppp0 -m state --state RELATED,ESTABLISHED -j ACCEPT</rule>
  <rule ipv="ipv4" table="filter" chain="FORWARD" priority="0">-i ppp1 -o eth0 -j ACCEPT</rule>
  <rule ipv="ipv4" table="filter" chain="FORWARD" priority="0">-i eht0 -o ppp1 -m state --state RELATED,ESTABLISHED -j ACCEPT</rule>
  <rule ipv="ipv4" table="filter" chain="FORWARD" priority="0">-i tun21 -o eth0 -j ACCEPT</rule>
  <rule ipv="ipv4" table="filter" chain="FORWARD" priority="0">-i eth0 -o tun21 -m state --state RELATED,ESTABLISHED -j ACCEPT</rule>
  <rule ipv="ipv4" table="filter" chain="FORWARD" priority="0">-i tun12 -o eth0 -j ACCEPT</rule>
  <rule ipv="ipv4" table="filter" chain="FORWARD" priority="0">-i eth0 -o tun12 -m state --state RELATED,ESTABLISHED -j ACCEPT</rule>
  <rule ipv="ipv4" table="filter" chain="INPUT" priority="0">-p gre -j ACCEPT</rule>
</direct>
HERE

cat > /etc/firewalld/zones/public.xml << HERE
<?xml version="1.0" encoding="utf-8"?>
<zone>
  <short>Public</short>
  <description>For use in public areas. You do not trust the other computers on networks to not harm your computer. Only selected incoming connections are accepted.</description>
  <service name="ssh"/>
  <service name="dhcpv6-client"/>
  <service name="cockpit"/>
  <service name="ipsec"/>
  <port port="80" protocol="tcp"/>
  <port port="443" protocol="tcp"/>
  <port port="1194" protocol="tcp"/>
  <port port="1194" protocol="udp"/>
  <port port="1701" protocol="tcp"/>
  <port port="1701" protocol="udp"/>
  <port port="1080" protocol="tcp"/>
  <port port="1080" protocol="udp"/>
  <port port="53" protocol="tcp"/>
  <port port="53" protocol="udp"/>
  <port port="67" protocol="udp"/>
  <port port="3128" protocol="tcp"/>
  <port port="1723" protocol="tcp"/>
  <port port="1723" protocol="udp"/>
  <port port="47" protocol="udp"/>
  <port port="47" protocol="tcp"/>
  <port port="3327" protocol="tcp"/>
  <port port="3327" protocol="udp"/>
  <port port="443" protocol="udp"/>
  <port port="2294" protocol="udp"/>
  <protocol value="gre"/>
</zone>
HERE

cat > /etc/firewalld/zones/trusted.xml << HERE
<?xml version="1.0" encoding="utf-8"?>
<zone target="ACCEPT">
  <short>Trusted</short>
  <description>All network connections are accepted.</description>
  <interface name="ppp0"/>
  <interface name="ppp1"/>
  <interface name="tun12"/>
  <interface name="tun21"/>
  <source address="10.0.0.0/8"/>
  <service name="ssh"/>
  <masquerade/>
</zone>
HERE

firewall-cmd --reload
 
 
