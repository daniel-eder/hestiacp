#!/bin/bash

# Hestia RHEL/CentOS installer v1.0

#----------------------------------------------------------#
#                  Variables&Functions                     #
#----------------------------------------------------------#
export PATH=$PATH:/sbin
RHOST='rhel.hestiacp.com'
GPG='gpg.hestiacp.com'
VERSION='rhel'
HESTIA='/usr/local/hestia'
LOG="/root/hst_install_backups/hst_install-$(date +%d%m%Y%H%M).log"
memory=$(grep 'MemTotal' /proc/meminfo |tr ' ' '\n' |grep [0-9])
hst_backups="/root/hst_install_backups/$(date +%d%m%Y%H%M)"
arch=$(uname -i)
spinner="/-\|"
os=$(cut -f 1 -d ' ' /etc/redhat-release)
release=$(grep -o "[0-9]" /etc/redhat-release |head -n1)
codename="${os}_$release"
HESTIA_INSTALL_DIR="$HESTIA/install/rhel"

# Defining software pack for all distros
software="nginx awstats bc bind bind-libs bind-utils clamav-server clamav-update
    curl dovecot e2fsprogs exim expect fail2ban flex freetype ftp GeoIP httpd
    ImageMagick iptables-services jwhois lsof mailx mariadb mariadb-server mc
    mod_fcgid mod_ruid2 mod_ssl net-tools ntp openssh-clients pcre php
    php-bcmath php-cli php-common php-fpm php-gd php-imap php-mbstring
    php-mcrypt phpMyAdmin php-mysql php-pdo phpPgAdmin php-pgsql php-soap
    php-tidy php-xml php-xmlrpc postgresql postgresql-contrib
    postgresql-server proftpd roundcubemail rrdtool rsyslog screen
    spamassassin sqlite sudo tar telnet unzip hestia hestia-ioncube hestia-nginx
    hestia-php hestia-softaculous vim-common vsftpd webalizer which zip"

# Defining help function
help() {
    echo "Usage: $0 [OPTIONS]
  -a, --apache            Install Apache        [yes|no]  default: yes
  -n, --nginx             Install Nginx         [yes|no]  default: yes
  -w, --phpfpm            Install PHP-FPM       [yes|no]  default: no
  -o, --multiphp          Install Multi-PHP     [yes|no]  default: no
  -v, --vsftpd            Install Vsftpd        [yes|no]  default: yes
  -j, --proftpd           Install ProFTPD       [yes|no]  default: no
  -k, --named             Install Bind          [yes|no]  default: yes
  -m, --mysql             Install MariaDB       [yes|no]  default: yes
  -g, --postgresql        Install PostgreSQL    [yes|no]  default: no
  -x, --exim              Install Exim          [yes|no]  default: yes
  -z, --dovecot           Install Dovecot       [yes|no]  default: yes
  -c, --clamav            Install ClamAV        [yes|no]  default: yes
  -t, --spamassassin      Install SpamAssassin  [yes|no]  default: yes
  -i, --iptables          Install Iptables      [yes|no]  default: yes
  -b, --fail2ban          Install Fail2ban      [yes|no]  default: yes
  -q, --quota             Filesystem Quota      [yes|no]  default: no
  -d, --api               Activate API          [yes|no]  default: yes
  -r, --port              Change Backend Port             default: 8083
  -l, --lang              Default language                default: en
  -y, --interactive       Interactive install   [yes|no]  default: yes
  -s, --hostname          Set hostname
  -e, --email             Set admin email
  -p, --password          Set admin password
  -D, --with-rpms         Path to Hestia rpms
  -f, --force             Force installation
  -h, --help              Print this help

  Example: bash $0 -e demo@hestiacp.com -p p4ssw0rd --apache no --phpfpm yes"
    exit 1
}

# Defining file download function
download_file() {
    wget $1 -q --show-progress --progress=bar:force
}

# Defining password-gen function
gen_pass() {
    MATRIX='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    LENGTH=16
    while [ ${n:=1} -le $LENGTH ]; do
        PASS="$PASS${MATRIX:$(($RANDOM%${#MATRIX})):1}"
        let n+=1
    done
    echo "$PASS"
}

# Defining return code check function
check_result() {
    if [ $1 -ne 0 ]; then
        echo "Error: $2"
        exit $1
    fi
}

# Defining function to set default value
set_default_value() {
    eval variable=\$$1
    if [ -z "$variable" ]; then
        eval $1=$2
    fi
    if [ "$variable" != 'yes' ] && [ "$variable" != 'no' ]; then
        eval $1=$2
    fi
}

# Defining function to set default language value
set_default_lang() {
    if [ -z "$lang" ]; then
        eval lang=$1
    fi
    lang_list="
        ar cz el fa hu ja no pt se ua
        bs da en fi id ka pl ro tr vi
        cn de es fr it nl pt-BR ru tw
        bg ko sr th ur"
    if !(echo $lang_list |grep -w $lang > /dev/null 2>&1); then
        eval lang=$1
    fi
}

# Define the default backend port
set_default_port() {
    if [ -z "$port" ]; then
        eval port=$1
    fi
}


#----------------------------------------------------------#
#                    Verifications                         #
#----------------------------------------------------------#

# Creating temporary file
tmpfile=$(mktemp -p /tmp)

# Translating argument to --gnu-long-options
for arg; do
    delim=""
    case "$arg" in
        --apache)               args="${args}-a " ;;
        --nginx)                args="${args}-n " ;;
        --phpfpm)               args="${args}-w " ;;
        --vsftpd)               args="${args}-v " ;;
        --proftpd)              args="${args}-j " ;;
        --named)                args="${args}-k " ;;
        --mysql)                args="${args}-m " ;;
        --postgresql)           args="${args}-g " ;;
        --exim)                 args="${args}-x " ;;
        --dovecot)              args="${args}-z " ;;
        --clamav)               args="${args}-c " ;;
        --spamassassin)         args="${args}-t " ;;
        --iptables)             args="${args}-i " ;;
        --fail2ban)             args="${args}-b " ;;
        --multiphp)             args="${args}-o " ;;
        --quota)                args="${args}-q " ;;
        --port)                 args="${args}-r " ;;
        --lang)                 args="${args}-l " ;;
        --interactive)          args="${args}-y " ;;
        --api)                  args="${args}-d " ;;
        --hostname)             args="${args}-s " ;;
        --email)                args="${args}-e " ;;
        --password)             args="${args}-p " ;;
        --force)                args="${args}-f " ;;
        --with-rpms)            args="${args}-D " ;;
        --help)                 args="${args}-h " ;;
        *)                      [[ "${arg:0:1}" == "-" ]] || delim="\""
                                args="${args}${delim}${arg}${delim} ";;
    esac
done
eval set -- "$args"

# Parsing arguments
while getopts "a:n:w:v:j:k:m:g:d:x:z:c:t:i:b:r:o:q:l:y:s:e:p:D:fh" Option; do
    case $Option in
        a) apache=$OPTARG ;;            # Apache
        n) nginx=$OPTARG ;;             # Nginx
        w) phpfpm=$OPTARG ;;            # PHP-FPM
        o) multiphp=$OPTARG ;;          # Multi-PHP
        v) vsftpd=$OPTARG ;;            # Vsftpd
        j) proftpd=$OPTARG ;;           # Proftpd
        k) named=$OPTARG ;;             # Named
        m) mysql=$OPTARG ;;             # MySQL
        g) postgresql=$OPTARG ;;        # PostgreSQL
        x) exim=$OPTARG ;;              # Exim
        z) dovecot=$OPTARG ;;           # Dovecot
        c) clamd=$OPTARG ;;             # ClamAV
        t) spamd=$OPTARG ;;             # SpamAssassin
        i) iptables=$OPTARG ;;          # Iptables
        b) fail2ban=$OPTARG ;;          # Fail2ban
        q) quota=$OPTARG ;;             # FS Quota
        r) port=$OPTARG ;;              # Backend Port
        l) lang=$OPTARG ;;              # Language
        d) api=$OPTARG ;;               # Activate API
        y) interactive=$OPTARG ;;       # Interactive install
        s) servername=$OPTARG ;;        # Hostname
        e) email=$OPTARG ;;             # Admin email
        p) vpass=$OPTARG ;;             # Admin password
        D) withrpms=$OPTARG ;;          # Hestia rpms path
        f) force='yes' ;;               # Force install
        h) help ;;                      # Help
        *) help ;;                      # Print help (default)
    esac
done

# Defining default software stack
set_default_value 'nginx' 'yes'
set_default_value 'apache' 'yes'
set_default_value 'phpfpm' 'no'
set_default_value 'multiphp' 'no'
set_default_value 'vsftpd' 'yes'
set_default_value 'proftpd' 'no'
set_default_value 'named' 'yes'
set_default_value 'mysql' 'yes'
set_default_value 'postgresql' 'no'
set_default_value 'exim' 'yes'
set_default_value 'dovecot' 'yes'
if [ $memory -lt 1500000 ]; then
    set_default_value 'clamd' 'no'
    set_default_value 'spamd' 'no'
else
    set_default_value 'clamd' 'yes'
    set_default_value 'spamd' 'yes'
fi
set_default_value 'iptables' 'yes'
set_default_value 'fail2ban' 'yes'
set_default_value 'quota' 'no'
set_default_value 'interactive' 'yes'
set_default_value 'api' 'yes'
set_default_port '8083'
set_default_lang 'en'

# Checking software conflicts

if [ "$multiphp" = 'yes' ]; then
    phpfpm='yes'
fi
if [ "$proftpd" = 'yes' ]; then
    vsftpd='no'
fi
if [ "$exim" = 'no' ]; then
    clamd='no'
    spamd='no'
    dovecot='no'
fi
if [ "$iptables" = 'no' ]; then
    fail2ban='no'
fi

# Checking root permissions
if [ "x$(id -u)" != 'x0' ]; then
    check_result 1 "Script can be run executed only by root"
fi

# Checking admin user account
if [ ! -z "$(grep ^admin: /etc/passwd /etc/group)" ] && [ -z "$force" ]; then
    echo 'Please remove admin user account before proceeding.'
    echo 'If you want to do it automatically run installer with -f option:'
    echo -e "Example: bash $0 --force\n"
    check_result 1 "User admin exists"
fi

# Check if a default webserver was set
if [ $apache = 'no' ] && [ $nginx = 'no' ]; then
    check_result 1 "No web server was selected"
fi

# Clear the screen once launch permissions have been verified
clear

# Welcome message
echo "Welcome to the Hestia Control Panel installer!"
echo 
echo "Please wait a moment while we update your system's repositories and"
echo "install any necessary dependencies required to proceed with the installation..."
echo 

# Creating backup directory
mkdir -p $hst_backups

# Checking ntpdate
if [ ! -e '/usr/sbin/ntpdate' ]; then
    echo "(*) Installing ntpdate..."
    yum -y install ntpdate >> $LOG
    check_result $? "Can't install ntpdate"
fi

# Checking wget
if [ ! -e '/usr/bin/wget' ]; then
    echo "(*) Installing wget..."
    yum -y install wget >> $LOG
    check_result $? "Can't install wget"
fi

# Check repository availability
wget --quiet "https://$GPG/rhel_signing.key" -O /dev/null
check_result $? "Unable to connect to the Hestia RHEL repository"

# Checking installed packages
tmpfile=$(mktemp -p /tmp)
rpm -qa > $tmpfile
for pkg in exim mariadb-server httpd nginx hestia postfix; do
    if [ ! -z "$(grep $pkg $tmpfile)" ]; then
        conflicts="$pkg* $conflicts"
    fi
done
rm -f $tmpfile
if [ ! -z "$conflicts" ] && [ -z "$force" ]; then
    echo '!!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!!'
    echo
    echo 'WARNING: The following packages are already installed'
    echo "$conflicts"
    echo
    echo 'It is highly recommended that you remove them before proceeding.'
    echo
    echo '!!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!!'
    echo
    read -p 'Would you like to remove the conflicting packages? [y/n] ' answer
    if [ "$answer" = 'y' ] || [ "$answer" = 'Y'  ]; then
        yum remove $conflicts -y
        check_result $? 'yum remove failed'
        unset $answer
    else
        check_result 1 "Hestia Control Panel should be installed on a clean server."
    fi
fi


#----------------------------------------------------------#
#                       Brief Info                         #
#----------------------------------------------------------#

# Printing nice ASCII logo
clear
echo
echo '  _   _           _   _        ____ ____  '
echo ' | | | | ___  ___| |_(_) __ _ / ___|  _ \ '
echo ' | |_| |/ _ \/ __| __| |/ _` | |   | |_) |'
echo ' |  _  |  __/\__ \ |_| | (_| | |___|  __/ '
echo ' |_| |_|\___||___/\__|_|\__,_|\____|_|    '
echo
echo '                      Hestia Control Panel'
echo '                                    v1.1.0'
echo -e "\n"
echo "===================================================================="
echo -e "\n"
echo 'The following server components will be installed on your system:'
echo

# Web stack
if [ "$nginx" = 'yes' ]; then
    echo '   - NGINX Web / Proxy Server'
fi
if [ "$apache" = 'yes' ] && [ "$nginx" = 'no' ] ; then
    echo '   - Apache Web Server'
fi
if [ "$apache" = 'yes' ] && [ "$nginx"  = 'yes' ] ; then
    echo '   - Apache Web Server (as backend)'
fi
if [ "$phpfpm"  = 'yes' ] && [ "$multiphp" = 'no' ]; then
    echo '   - PHP-FPM Application Server'
fi
if [ "$multiphp"  = 'yes' ]; then
    echo '   - Multi-PHP Environment'
fi

# DNS stack
if [ "$named" = 'yes' ]; then
    echo '   - Bind DNS Server'
fi

# Mail stack
if [ "$exim" = 'yes' ]; then
    echo -n '   - Exim Mail Server'
    if [ "$clamd" = 'yes'  ] ||  [ "$spamd" = 'yes' ] ; then
        echo -n ' + '
        if [ "$clamd" = 'yes' ]; then
            echo -n 'ClamAV '
        fi
        if [ "$spamd" = 'yes' ]; then
            if [ "$clamd" = 'yes' ]; then
                echo -n '+ '
            fi
            echo -n 'SpamAssassin'
        fi
    fi
    echo
    if [ "$dovecot" = 'yes' ]; then
        echo '   - Dovecot POP3/IMAP Server'
    fi
fi

# Database stack
if [ "$mysql" = 'yes' ]; then
        echo '   - MariaDB Database Server'
fi
if [ "$postgresql" = 'yes' ]; then
    echo '   - PostgreSQL Database Server'
fi

# FTP stack
if [ "$vsftpd" = 'yes' ]; then
    echo '   - Vsftpd FTP Server'
fi
if [ "$proftpd" = 'yes' ]; then
    echo '   - ProFTPD FTP Server'
fi

# Firewall stack
if [ "$iptables" = 'yes' ]; then
    echo -n '   - Firewall (Iptables)'
fi
if [ "$iptables" = 'yes' ] && [ "$fail2ban" = 'yes' ]; then
    echo -n ' + Fail2Ban Access Monitor'
fi
echo -e "\n"
echo "===================================================================="
echo -e "\n"

# Asking for confirmation to proceed
if [ "$interactive" = 'yes' ]; then
    read -p 'Would you like to continue with the installation? [Y/N]: ' answer
    if [ "$answer" != 'y' ] && [ "$answer" != 'Y'  ]; then
        echo 'Goodbye'
        exit 1
    fi

    # Asking for contact email
    if [ -z "$email" ]; then
        read -p 'Please enter admin email address: ' email
    fi

    # Asking to set FQDN hostname
    if [ -z "$servername" ]; then
        read -p "Please enter FQDN hostname [$(hostname -f)]: " servername
    fi
fi

# Generating admin password if it wasn't set
if [ -z "$vpass" ]; then
    vpass=$(gen_pass)
fi

# Set hostname if it wasn't set
if [ -z "$servername" ]; then
    servername=$(hostname -f)
fi

# Set FQDN if it wasn't set
mask1='(([[:alnum:]](-?[[:alnum:]])*)\.)'
mask2='*[[:alnum:]](-?[[:alnum:]])+\.[[:alnum:]]{2,}'
if ! [[ "$servername" =~ ^${mask1}${mask2}$ ]]; then
    if [ ! -z "$servername" ]; then
        servername="$servername.example.com"
    else
        servername="example.com"
    fi
    echo "127.0.0.1 $servername" >> /etc/hosts
fi

# Set email if it wasn't set
if [ -z "$email" ]; then
    email="admin@$servername"
fi

# Defining backup directory
echo -e "Installation backup directory: $hst_backups"

# Print Log File Path
echo "Installation log file: $LOG"

# Print new line
echo


#----------------------------------------------------------#
#                      Checking swap                       #
#----------------------------------------------------------#

# Checking swap on small instances
if [ -z "$(swapon -s)" ] && [ $memory -lt 1000000 ]; then
    fallocate -l 1G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile   none    swap    sw    0   0" >> /etc/fstab
fi


#----------------------------------------------------------#
#                   Install repository                     #
#----------------------------------------------------------#

# Updating system
echo "Adding required repositories to proceed with installation:"
echo

# Installing EPEL repository
yum install epel-release -y
check_result $? "Can't install EPEL repository"

# Installing Remi repository
rpm -Uvh http://rpms.remirepo.net/enterprise/remi-release-$release.rpm
check_result $? "Can't install REMI repository"
sed -i "s/enabled=0/enabled=1/g" /etc/yum.repos.d/remi.repo

# Installing Nginx repository
nrepo="/etc/yum.repos.d/nginx.repo"
echo "[nginx]" > $nrepo
echo "name=nginx repo" >> $nrepo
echo "baseurl=https://nginx.org/packages/centos/$release/\$basearch/" >> $nrepo
echo "gpgcheck=0" >> $nrepo
echo "enabled=1" >> $nrepo

# Installing Hestia repository
vrepo='/etc/yum.repos.d/hestia.repo'
echo "[hestia]" > $vrepo
echo "name=Hestia - $REPO" >> $vrepo
echo "baseurl=http://$RHOST/$REPO/$release/\$basearch/" >> $vrepo
echo "enabled=1" >> $vrepo
echo "gpgcheck=1" >> $vrepo
echo "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-HESTIA" >> $vrepo
wget c.hestiacp.com/GPG.txt -O /etc/pki/rpm-gpg/RPM-GPG-KEY-HESTIA


#----------------------------------------------------------#
#                         Backup                           #
#----------------------------------------------------------#

# Creating backup directory tree
mkdir -p $hst_backups
cd $hst_backups
mkdir nginx httpd php vsftpd proftpd bind exim4 dovecot clamd
mkdir spamassassin mysql postgresql hestia

# Backup nginx configuration
service nginx stop > /dev/null 2>&1
cp -r /etc/nginx/* $hst_backups/nginx > /dev/null 2>&1

# Backup Apache configuration
service httpd stop > /dev/null 2>&1
cp -r /etc/httpd/* $hst_backups/httpd > /dev/null 2>&1

# Backup PHP-FPM configuration
service php-fpm stop >/dev/null 2>&1
cp /etc/php.ini $hst_backups/php > /dev/null 2>&1
cp -r /etc/php.d  $hst_backups/php > /dev/null 2>&1
cp /etc/php-fpm.conf $hst_backups/php-fpm > /dev/null 2>&1
mv -f /etc/php-fpm.d/* $hst_backups/php-fpm/ > /dev/null 2>&1

# Backup Bind configuration
yum remove bind-chroot > /dev/null 2>&1
service named stop > /dev/null 2>&1
cp /etc/named.conf $hst_backups/named >/dev/null 2>&1

# Backup Vsftpd configuration
service vsftpd stop > /dev/null 2>&1
cp /etc/vsftpd/vsftpd.conf $hst_backups/vsftpd >/dev/null 2>&1

# Backup ProFTPD configuration
service proftpd stop > /dev/null 2>&1
cp /etc/proftpd.conf $hst_backups/proftpd >/dev/null 2>&1

# Backup Exim configuration
service exim stop > /dev/null 2>&1
cp -r /etc/exim/* $hst_backups/exim >/dev/null 2>&1

# Backup ClamAV configuration
service clamd stop > /dev/null 2>&1
cp /etc/clamd.conf $hst_backups/clamd >/dev/null 2>&1
cp -r /etc/clamd.d $hst_backups/clamd >/dev/null 2>&1

# Backup SpamAssassin configuration
service spamassassin stop > /dev/null 2>&1
cp -r /etc/mail/spamassassin/* $hst_backups/spamassassin >/dev/null 2>&1

# Backup Dovecot configuration
service dovecot stop > /dev/null 2>&1
cp /etc/dovecot.conf $hst_backups/dovecot > /dev/null 2>&1
cp -r /etc/dovecot/* $hst_backups/dovecot > /dev/null 2>&1

# Backup MySQL/MariaDB configuration and data
service mysql stop > /dev/null 2>&1
service mysqld stop > /dev/null 2>&1
service mariadb stop > /dev/null 2>&1
mv /var/lib/mysql $hst_backups/mysql/mysql_datadir >/dev/null 2>&1
cp /etc/my.cnf $hst_backups/mysql > /dev/null 2>&1
cp /etc/my.cnf.d $hst_backups/mysql > /dev/null 2>&1
mv /root/.my.cnf  $hst_backups/mysql > /dev/null 2>&1

# Backup PostgreSQL configuration and data
service postgresql stop > /dev/null 2>&1
mv /var/lib/pgsql/data $hst_backups/postgresql/  >/dev/null 2>&1

# Backup Hestia
service hestia stop > /dev/null 2>&1
cp -r $HESTIA* $hst_backups/hestia > /dev/null 2>&1
yum -y remove hestia hestia-nginx hestia-php > /dev/null 2>&1
rm -rf $HESTIA > /dev/null 2>&1


#----------------------------------------------------------#
#                     Package Includes                     #
#----------------------------------------------------------#

if [ "$phpfpm" = 'yes' ]; then
    fpm="php$fpm_v php$fpm_v-common php$fpm_v-bcmath php$fpm_v-cli
         php$fpm_v-curl php$fpm_v-fpm php$fpm_v-gd php$fpm_v-intl
         php$fpm_v-mysql php$fpm_v-soap php$fpm_v-xml php$fpm_v-zip
         php$fpm_v-mbstring php$fpm_v-json php$fpm_v-bz2 php$fpm_v-pspell
         php$fpm_v-imagick"
    software="$software $fpm"
fi


#----------------------------------------------------------#
#                     Package Excludes                     #
#----------------------------------------------------------#

# Excluding packages
if [ "$nginx" = 'no'  ]; then
    software=$(echo "$software" | sed -e "s/\bnginx\b/ /")
fi
if [ "$apache" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/httpd//")
    software=$(echo "$software" | sed -e "s/mod_ssl//")
    software=$(echo "$software" | sed -e "s/mod_fcgid//")
    software=$(echo "$software" | sed -e "s/mod_ruid2//")
fi
if [ "$phpfpm" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/php-fpm//")
fi
if [ "$vsftpd" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/vsftpd//")
fi
if [ "$proftpd" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/proftpd//")
fi
if [ "$named" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/bind //")
fi
if [ "$exim" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/exim//")
    software=$(echo "$software" | sed -e "s/dovecot//")
    software=$(echo "$software" | sed -e "s/clamd//")
    software=$(echo "$software" | sed -e "s/clamav-server//")
    software=$(echo "$software" | sed -e "s/clamav-update//")
    software=$(echo "$software" | sed -e "s/spamassassin//")
    software=$(echo "$software" | sed -e "s/roundcube-core//")
    software=$(echo "$software" | sed -e "s/roundcube-mysql//")
    software=$(echo "$software" | sed -e "s/roundcube-plugins//")
fi
if [ "$clamd" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/clamav-daemon//")
fi
if [ "$spamd" = 'no' ]; then
    software=$(echo "$software" | sed -e 's/spamassassin//')
fi
if [ "$dovecot" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/dovecot-imapd//")
    software=$(echo "$software" | sed -e "s/dovecot-pop3d//")
    software=$(echo "$software" | sed -e "s/roundcube-core//")
    software=$(echo "$software" | sed -e "s/roundcube-mysql//")
    software=$(echo "$software" | sed -e "s/roundcube-plugins//")
fi
if [ "$mysql" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/mariadb-server//")
    software=$(echo "$software" | sed -e "s/mariadb-client//")
    software=$(echo "$software" | sed -e "s/mariadb-common//")
    software=$(echo "$software" | sed -e "s/php$fpm_v-mysql//")
    if [ "$multiphp" = 'yes' ]; then
        for v in "${multiphp_v[@]}"; do
            software=$(echo "$software" | sed -e "s/php$v-mysql//")
            software=$(echo "$software" | sed -e "s/php$v-bz2//")
        done
fi
    software=$(echo "$software" | sed -e "s/phpmyadmin//")
fi
if [ "$postgresql" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/postgresql-contrib//")
    software=$(echo "$software" | sed -e "s/postgresql//")
    software=$(echo "$software" | sed -e "s/php$fpm_v-pgsql//")
    if [ "$multiphp" = 'yes' ]; then
        for v in "${multiphp_v[@]}"; do
            software=$(echo "$software" | sed -e "s/php$v-pgsql//")
        done
fi
    software=$(echo "$software" | sed -e "s/phppgadmin//")
fi
if [ "$iptables" = 'no' ] || [ "$fail2ban" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/fail2ban//")
fi
if [ "$phpfpm" = 'yes' ]; then
    software=$(echo "$software" | sed -e "s/php$fpm_v-cgi//")
fi
if [ -d "$withdebs" ]; then
    software=$(echo "$software" | sed -e "s/hestia-nginx//")
    software=$(echo "$software" | sed -e "s/hestia-php//")
    software=$(echo "$software" | sed -e "s/hestia//")
fi


#----------------------------------------------------------#
#                     Install packages                     #
#----------------------------------------------------------#

# Installing rpm packages
yum install -y $software
if [ $? -ne 0 ]; then
    yum -y --disablerepo=* \
        --enablerepo="*base,*updates,nginx,epel,hestia,remi*" \
        install $software
fi
check_result $? "yum install failed"


#----------------------------------------------------------#
#                     Configure system                     #
#----------------------------------------------------------#

# Restarting rsyslog
service rsyslog restart > /dev/null 2>&1

# Checking ipv6 on loopback interface
check_lo_ipv6=$(/sbin/ip addr | grep 'inet6')
check_rc_ipv6=$(grep 'scope global dev lo' /etc/rc.local)
if [ ! -z "$check_lo_ipv6)" ] && [ -z "$check_rc_ipv6" ]; then
    ip addr add ::2/128 scope global dev lo
    echo "# Hestia: Workraround for openssl validation func" >> /etc/rc.local
    echo "ip addr add ::2/128 scope global dev lo" >> /etc/rc.local
    chmod a+x /etc/rc.local
fi

# Disabling SELinux
if [ -e '/etc/sysconfig/selinux' ]; then
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0 2>/dev/null
fi

# Disabling iptables
service iptables stop
service firewalld stop >/dev/null 2>&1


# Configuring NTP synchronization
echo '#!/bin/sh' > /etc/cron.daily/ntpdate
echo "$(which ntpdate) -s pool.ntp.org" >> /etc/cron.daily/ntpdate
chmod 775 /etc/cron.daily/ntpdate
ntpdate -s pool.ntp.org

# Disabling webalizer routine
rm -f /etc/cron.daily/00webalizer

# Adding backup user
adduser backup 2>/dev/null
ln -sf /home/backup /backup
chmod a+x /backup

# Set directory color
echo 'LS_COLORS="$LS_COLORS:di=00;33"' >> /etc/profile

# Register /sbin/nologin and /usr/sbin/nologin
echo "/sbin/nologin" >> /etc/shells
echo "/usr/sbin/nologin" >> /etc/shells

# Changing default systemd interval
if [ "$release" -eq '7' ]; then
    # Hi Lennart
    echo "DefaultStartLimitInterval=1s" >> /etc/systemd/system.conf
    echo "DefaultStartLimitBurst=60" >> /etc/systemd/system.conf
    systemctl daemon-reexec
fi


#----------------------------------------------------------#
#                     Configure HESTIA                      #
#----------------------------------------------------------#

# Installing sudo configuration
mkdir -p /etc/sudoers.d
cp -f $hestiacp/sudo/admin /etc/sudoers.d/
chmod 440 /etc/sudoers.d/admin

# Configuring system env
echo "export HESTIA='$HESTIA'" > /etc/profile.d/hestia.sh
chmod 755 /etc/profile.d/hestia.sh
source /etc/profile.d/hestia.sh
echo 'PATH=$PATH:'$HESTIA'/bin' >> /root/.bash_profile
echo 'export PATH' >> /root/.bash_profile
source /root/.bash_profile

# Configuring logrotate for hestia logs
cp -f $hestiacp/logrotate/hestia /etc/logrotate.d/

# Building directory tree and creating some blank files for Hestia
mkdir -p $HESTIA/conf $HESTIA/log $HESTIA/ssl $HESTIA/data/ips \
    $HESTIA/data/queue $HESTIA/data/users $HESTIA/data/firewall \
    $HESTIA/data/sessions
touch $HESTIA/data/queue/backup.pipe $HESTIA/data/queue/disk.pipe \
    $HESTIA/data/queue/webstats.pipe $HESTIA/data/queue/restart.pipe \
    $HESTIA/data/queue/traffic.pipe $HESTIA/log/system.log \
    $HESTIA/log/nginx-error.log $HESTIA/log/auth.log
chmod 750 $HESTIA/conf $HESTIA/data/users $HESTIA/data/ips $HESTIA/log
chmod -R 750 $HESTIA/data/queue
chmod 660 $HESTIA/log/*
rm -f /var/log/hestia
ln -s $HESTIA/log /var/log/hestia
chmod 770 $HESTIA/data/sessions

# Generating Hestia configuration
rm -f $HESTIA/conf/hestia.conf > /dev/null 2>&1
touch $HESTIA/conf/hestia.conf
chmod 660 $HESTIA/conf/hestia.conf

# Web stack
if [ "$apache" = 'yes' ] && [ "$nginx" = 'no' ] ; then
    echo "WEB_SYSTEM='httpd'" >> $HESTIA/conf/hestia.conf
    echo "WEB_RGROUPS='apache'" >> $HESTIA/conf/hestia.conf
    echo "WEB_PORT='80'" >> $HESTIA/conf/hestia.conf
    echo "WEB_SSL_PORT='443'" >> $HESTIA/conf/hestia.conf
    echo "WEB_SSL='mod_ssl'"  >> $HESTIA/conf/hestia.conf
    echo "STATS_SYSTEM='awstats'" >> $HESTIA/conf/hestia.conf
fi
if [ "$apache" = 'yes' ] && [ "$nginx"  = 'yes' ] ; then
    echo "WEB_SYSTEM='httpd'" >> $HESTIA/conf/hestia.conf
    echo "WEB_RGROUPS='apache'" >> $HESTIA/conf/hestia.conf
    echo "WEB_PORT='8080'" >> $HESTIA/conf/hestia.conf
    echo "WEB_SSL_PORT='8443'" >> $HESTIA/conf/hestia.conf
    echo "WEB_SSL='mod_ssl'"  >> $HESTIA/conf/hestia.conf
    echo "PROXY_SYSTEM='nginx'" >> $HESTIA/conf/hestia.conf
    echo "PROXY_PORT='80'" >> $HESTIA/conf/hestia.conf
    echo "PROXY_SSL_PORT='443'" >> $HESTIA/conf/hestia.conf
    echo "STATS_SYSTEM='awstats'" >> $HESTIA/conf/hestia.conf
fi
if [ "$apache" = 'no' ] && [ "$nginx"  = 'yes' ]; then
    echo "WEB_SYSTEM='nginx'" >> $HESTIA/conf/hestia.conf
    echo "WEB_PORT='80'" >> $HESTIA/conf/hestia.conf
    echo "WEB_SSL_PORT='443'" >> $HESTIA/conf/hestia.conf
    echo "WEB_SSL='openssl'"  >> $HESTIA/conf/hestia.conf
    echo "STATS_SYSTEM='awstats'" >> $HESTIA/conf/hestia.conf
fi

if [ "$phpfpm" = 'yes' ] || [ "$multiphp" = 'yes' ]; then
        echo "WEB_BACKEND='php-fpm'" >> $HESTIA/conf/hestia.conf
fi

# Database stack
if [ "$mysql" = 'yes' ]; then
    installed_db_types='mysql'
fi

if [ "$pgsql" = 'yes' ]; then
    installed_db_types="$installed_db_type,pgsql"
fi

if [ ! -z "$installed_db_types" ]; then
    db=$(echo "$installed_db_types" |\
        sed "s/,/\n/g"|\
        sort -r -u |\
        sed "/^$/d"|\
        sed ':a;N;$!ba;s/\n/,/g')
    echo "DB_SYSTEM='$db'" >> $HESTIA/conf/hestia.conf
fi

# FTP stack
if [ "$vsftpd" = 'yes' ]; then
    echo "FTP_SYSTEM='vsftpd'" >> $HESTIA/conf/hestia.conf
fi
if [ "$proftpd" = 'yes' ]; then
    echo "FTP_SYSTEM='proftpd'" >> $HESTIA/conf/hestia.conf
fi

# DNS stack
if [ "$named" = 'yes' ]; then
    echo "DNS_SYSTEM='named'" >> $HESTIA/conf/hestia.conf
fi

# Mail stack
if [ "$exim" = 'yes' ]; then
    echo "MAIL_SYSTEM='exim'" >> $HESTIA/conf/hestia.conf
    if [ "$clamd" = 'yes'  ]; then
        echo "ANTIVIRUS_SYSTEM='clamav-daemon'" >> $HESTIA/conf/hestia.conf
    fi
    if [ "$spamd" = 'yes' ]; then
        echo "ANTISPAM_SYSTEM='spamassassin'" >> $HESTIA/conf/hestia.conf
    fi
    if [ "$dovecot" = 'yes' ]; then
        echo "IMAP_SYSTEM='dovecot'" >> $HESTIA/conf/hestia.conf
    fi
fi

# Cron daemon
echo "CRON_SYSTEM='crond'" >> $HESTIA/conf/hestia.conf

# Firewall stack
if [ "$iptables" = 'yes' ]; then
    echo "FIREWALL_SYSTEM='iptables'" >> $HESTIA/conf/hestia.conf
fi
if [ "$iptables" = 'yes' ] && [ "$fail2ban" = 'yes' ]; then
    echo "FIREWALL_EXTENSION='fail2ban'" >> $HESTIA/conf/hestia.conf
fi

# Disk quota
if [ "$quota" = 'yes' ]; then
    echo "DISK_QUOTA='yes'" >> $HESTIA/conf/hestia.conf
fi

# Backups
echo "BACKUP_SYSTEM='local'" >> $HESTIA/conf/hestia.conf

# Language
echo "LANGUAGE='$lang'" >> $HESTIA/conf/hestia.conf

# Version & Release Branch
echo "VERSION='1.1.0'" >> $HESTIA/conf/hestia.conf
echo "RELEASE_BRANCH='release'" >> $HESTIA/conf/hestia.conf

# Installing hosting packages
cp -rf $HESTIA_INSTALL_DIR/packages $HESTIA/data/

# Update nameservers in hosting package
IFS='.' read -r -a domain_elements <<< "$servername"
if [ ! -z "${domain_elements[-2]}" ] && [ ! -z "${domain_elements[-1]}" ]; then
    serverdomain="${domain_elements[-2]}.${domain_elements[-1]}"
    sed -i s/"domain.tld"/"$serverdomain"/g $HESTIA/data/packages/*.pkg
fi

# Installing templates
cp -rf $HESTIA_INSTALL_DIR/templates $HESTIA/data/

mkdir -p /var/www/html
mkdir -p /var/www/document_errors

# Install default success page
cp -rf $HESTIA_INSTALL_DIR/templates/web/unassigned/index.html /var/www/html/
cp -rf $HESTIA_INSTALL_DIR/templates/web/skel/document_errors/* /var/www/document_errors/

# Installing firewall rules
cp -rf $HESTIA_INSTALL_DIR/firewall $HESTIA/data/

# Configuring server hostname
$HESTIA/bin/v-change-sys-hostname $servername > /dev/null 2>&1

# Generating SSL certificate
echo "(*) Generating default self-signed SSL certificate..."
$HESTIA/bin/v-generate-ssl-cert $(hostname) $email 'US' 'California' \
     'San Francisco' 'Hestia Control Panel' 'IT' > /tmp/hst.pem

# Parsing certificate file
crt_end=$(grep -n "END CERTIFICATE-" /tmp/hst.pem |cut -f 1 -d:)
key_start=$(grep -n "BEGIN RSA" /tmp/hst.pem |cut -f 1 -d:)
key_end=$(grep -n  "END RSA" /tmp/hst.pem |cut -f 1 -d:)

# Adding SSL certificate
echo "(*) Adding SSL certificate to Hestia Control Panel..."
cd $HESTIA/ssl
sed -n "1,${crt_end}p" /tmp/hst.pem > certificate.crt
sed -n "$key_start,${key_end}p" /tmp/hst.pem > certificate.key
chown root:mail $HESTIA/ssl/*
chmod 660 $HESTIA/ssl/*
rm /tmp/hst.pem

# Adding nologin as a valid system shell
if [ -z "$(grep nologin /etc/shells)" ]; then
    echo "/usr/sbin/nologin" >> /etc/shells
fi

# Install dhparam.pem
cp -f $HESTIA_INSTALL_DIR/ssl/dhparam.pem /etc/ssl

#----------------------------------------------------------#
#                     Configure Nginx                      #
#----------------------------------------------------------#

if [ "$nginx" = 'yes' ]; then
    echo "(*) Configuring NGINX..."
    rm -f /etc/nginx/conf.d/*.conf
    cp -f $HESTIA_INSTALL_DIR/nginx/nginx.conf /etc/nginx/
    cp -f $HESTIA_INSTALL_DIR/nginx/status.conf /etc/nginx/conf.d/
    cp -f $HESTIA_INSTALL_DIR/nginx/phpmyadmin.inc /etc/nginx/conf.d/
    cp -f $HESTIA_INSTALL_DIR/nginx/phppgadmin.inc /etc/nginx/conf.d/
    cp -f $HESTIA_INSTALL_DIR/logrotate/nginx /etc/logrotate.d/
    mkdir -p /etc/nginx/conf.d/domains
    mkdir -p /var/log/nginx/domains
    mkdir -p /etc/systemd/system/nginx.service.d
    cd /etc/systemd/system/nginx.service.d
    echo "[Service]" > limits.conf
    echo "LimitNOFILE=500000" >> limits.conf

    # Update dns servers in nginx.conf
    dns_resolver=$(cat /etc/resolv.conf | grep -i '^nameserver' | cut -d ' ' -f2 | tr '\r\n' ' ' | xargs)
    for ip in $dns_resolver; do
        if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            resolver="$ip $resolver"
        fi
    done
    if [ ! -z "$resolver" ]; then
        sed -i "s/1.0.0.1 1.1.1.1/$resolver/g" /etc/nginx/nginx.conf
        sed -i "s/1.0.0.1 1.1.1.1/$resolver/g" /usr/local/hestia/nginx/conf/nginx.conf
    fi

    chkconfig nginx on
    service nginx start
    check_result $? "nginx start failed"

    # Workaround for OpenVZ/Virtuozzo
    if [ "$release" -ge '7' ] && [ -e "/proc/vz/veinfo" ]; then
        echo "#Hestia: workraround for networkmanager" >> /etc/rc.local
        echo "sleep 3 && service nginx restart" >> /etc/rc.local
    fi
fi


#----------------------------------------------------------#
#                    Configure Apache                      #
#----------------------------------------------------------#

if [ "$apache" = 'yes'  ]; then
    cp -f $hestiacp/httpd/httpd.conf /etc/httpd/conf/
    cp -f $hestiacp/httpd/status.conf /etc/httpd/conf.d/
    cp -f $hestiacp/httpd/ssl.conf /etc/httpd/conf.d/
    cp -f $hestiacp/httpd/ruid2.conf /etc/httpd/conf.d/
    cp -f $hestiacp/logrotate/httpd /etc/logrotate.d/
    if [ $release -lt 7 ]; then
        cd /etc/httpd/conf.d
        echo "MEFaccept 127.0.0.1" >> mod_extract_forwarded.conf
        echo > proxy_ajp.conf
    fi
    if [ -e "/etc/httpd/conf.modules.d/00-dav.conf" ]; then
        cd /etc/httpd/conf.modules.d
        sed -i "s/^/#/" 00-dav.conf 00-lua.conf 00-proxy.conf
    fi
    echo > /etc/httpd/conf.d/hestia.conf
    cd /var/log/httpd
    touch access_log error_log suexec.log
    chmod 640 access_log error_log suexec.log
    chmod -f 777 /var/lib/php/session
    chmod a+x /var/log/httpd
    mkdir -p /var/log/httpd/domains
    chmod 751 /var/log/httpd/domains
    if [ "$release" -ge 7 ]; then
        mkdir -p /etc/systemd/system/httpd.service.d
        cd /etc/systemd/system/httpd.service.d
        echo "[Service]" > limits.conf
        echo "LimitNOFILE=500000" >> limits.conf
    fi
    chkconfig httpd on
    service httpd start
    check_result $? "httpd start failed"

    # Workaround for OpenVZ/Virtuozzo
    if [ "$release" -ge '7' ] && [ -e "/proc/vz/veinfo" ]; then
        echo "#Hestia: workraround for networkmanager" >> /etc/rc.local
        echo "sleep 2 && service httpd restart" >> /etc/rc.local
    fi
fi


#----------------------------------------------------------#
#                     Configure PHP-FPM                    #
#----------------------------------------------------------#

if [ "$multiphp" = 'yes' ] ; then
    for v in "${multiphp_v[@]}"; do
        cp -r /etc/php/$v/ /root/hst_install_backups/php$v/
        rm -f /etc/php/$v/fpm/pool.d/*
        echo "(*) Install PHP version $v..."
        $HESTIA/bin/v-add-web-php "$v" > /dev/null 2>&1
    done
fi

if [ "$phpfpm" = 'yes' ]; then
    echo "(*) Configuring PHP-FPM..."
    $HESTIA/bin/v-add-web-php "$fpm_v" > /dev/null 2>&1
    cp -f $HESTIA_INSTALL_DIR/php-fpm/www.conf /etc/php/$fpm_v/fpm/pool.d/www.conf
    update-rc.d php$fpm_v-fpm defaults > /dev/null 2>&1
    systemctl start php$fpm_v-fpm >> $LOG
    check_result $? "php-fpm start failed"
    update-alternatives --set php /usr/bin/php$fpm_v > /dev/null 2>&1
fi


#----------------------------------------------------------#
#                     Configure PHP                        #
#----------------------------------------------------------#

ZONE=$(timedatectl 2>/dev/null|grep Timezone|awk '{print $2}')
if [ -e '/etc/sysconfig/clock' ]; then
    source /etc/sysconfig/clock
fi
if [ -z "$ZONE" ]; then
    ZONE='UTC'
fi
for pconf in $(find /etc/php* -name php.ini); do
    sed -i "s|;date.timezone =|date.timezone = $ZONE|g" $pconf
    sed -i 's%_open_tag = Off%_open_tag = On%g' $pconf
done


#----------------------------------------------------------#
#                    Configure Vsftpd                      #
#----------------------------------------------------------#

if [ "$vsftpd" = 'yes' ]; then
    cp -f $hestiacp/vsftpd/vsftpd.conf /etc/vsftpd/
    chkconfig vsftpd on
    service vsftpd start
    check_result $? "vsftpd start failed"
fi


#----------------------------------------------------------#
#                    Configure ProFTPD                     #
#----------------------------------------------------------#

if [ "$proftpd" = 'yes' ]; then
    cp -f $hestiacp/proftpd/proftpd.conf /etc/
    chkconfig proftpd on
    service proftpd start
    check_result $? "proftpd start failed"
fi


#----------------------------------------------------------#
#                  Configure MySQL/MariaDB                 #
#----------------------------------------------------------#

if [ "$mysql" = 'yes' ]; then

    mycnf="my-small.cnf"
    if [ $memory -gt 1200000 ]; then
        mycnf="my-medium.cnf"
    fi
    if [ $memory -gt 3900000 ]; then
        mycnf="my-large.cnf"
    fi

    mkdir -p /var/lib/mysql
    chown mysql:mysql /var/lib/mysql
    mkdir -p /etc/my.cnf.d

    if [ $release -lt 7 ]; then
        service='mysqld'
    else
        service='mariadb'
    fi

    cp -f $hestiacp/$service/$mycnf /etc/my.cnf
    chkconfig $service on
    service $service start
    if [ "$?" -ne 0 ]; then
        if [ -e "/proc/user_beancounters" ]; then
            # Fix for aio on OpenVZ
            sed -i "s/#innodb_use_native/innodb_use_native/g" /etc/my.cnf
        fi
        service $service start
        check_result $? "$service start failed"
    fi

    # Securing MySQL installation
    mpass=$(gen_pass)
    mysqladmin -u root password $mpass
    echo -e "[client]\npassword='$mpass'\n" > /root/.my.cnf
    chmod 600 /root/.my.cnf
    mysql -e "DELETE FROM mysql.user WHERE User=''"
    mysql -e "DROP DATABASE test" >/dev/null 2>&1
    mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
    mysql -e "DELETE FROM mysql.user WHERE user='' or password='';"
    mysql -e "FLUSH PRIVILEGES"

    # Configuring phpMyAdmin
    if [ "$apache" = 'yes' ]; then
        cp -f $hestiacp/pma/phpMyAdmin.conf /etc/httpd/conf.d/
    fi
    mysql < /usr/share/phpMyAdmin/sql/create_tables.sql
    p=$(gen_pass)
    mysql -e "GRANT ALL ON phpmyadmin.*
        TO phpmyadmin@localhost IDENTIFIED BY '$p'"
    cp -f $hestiacp/pma/config.inc.conf /etc/phpMyAdmin/config.inc.php
    sed -i "s/%blowfish_secret%/$(gen_pass 32)/g" /etc/phpMyAdmin/config.inc.php
    sed -i "s/%phpmyadmin_pass%/$p/g" /etc/phpMyAdmin/config.inc.php
    chmod 777 /var/lib/phpMyAdmin/temp
    chmod 777 /var/lib/phpMyAdmin/save
fi


#----------------------------------------------------------#
#                   Configure PostgreSQL                   #
#----------------------------------------------------------#

if [ "$postgresql" = 'yes' ]; then
    ppass=$(gen_pass)
    if [ $release -eq 5 ]; then
        service postgresql start
        sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$ppass'"
        service postgresql stop
        cp -f $hestiacp/postgresql/pg_hba.conf /var/lib/pgsql/data/
        service postgresql start
    else
        service postgresql initdb
        cp -f $hestiacp/postgresql/pg_hba.conf /var/lib/pgsql/data/
        service postgresql start
        sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$ppass'"
    fi
    # Configuring phpPgAdmin
    if [ "$apache" = 'yes' ]; then
        cp -f $hestiacp/pga/phpPgAdmin.conf /etc/httpd/conf.d/
    fi
    cp -f $hestiacp/pga/config.inc.php /etc/phpPgAdmin/
fi


#----------------------------------------------------------#
#                      Configure Bind                      #
#----------------------------------------------------------#

if [ "$named" = 'yes' ]; then
    cp -f $hestiacp/named/named.conf /etc/
    chown root:named /etc/named.conf
    chmod 640 /etc/named.conf
    chkconfig named on
    service named start
    check_result $? "named start failed"
fi


#----------------------------------------------------------#
#                      Configure Exim                      #
#----------------------------------------------------------#

if [ "$exim" = 'yes' ]; then
    gpasswd -a exim mail
    cp -f $hestiacp/exim/exim.conf /etc/exim/
    cp -f $hestiacp/exim/dnsbl.conf /etc/exim/
    cp -f $hestiacp/exim/spam-blocks.conf /etc/exim/
    touch /etc/exim/white-blocks.conf

    if [ "$spamd" = 'yes' ]; then
        sed -i "s/#SPAM/SPAM/g" /etc/exim/exim.conf
    fi
    if [ "$clamd" = 'yes' ]; then
        sed -i "s/#CLAMD/CLAMD/g" /etc/exim/exim.conf
    fi

    chmod 640 /etc/exim/exim.conf
    rm -rf /etc/exim/domains
    mkdir -p /etc/exim/domains

    rm -f /etc/alternatives/mta
    ln -s /usr/sbin/sendmail.exim /etc/alternatives/mta
    chkconfig sendmail off 2>/dev/null
    service sendmail stop 2>/dev/null
    chkconfig postfix off 2>/dev/null
    service postfix stop 2>/dev/null

    chkconfig exim on
    service exim start
    check_result $? "exim start failed"
fi


#----------------------------------------------------------#
#                     Configure Dovecot                    #
#----------------------------------------------------------#

if [ "$dovecot" = 'yes' ]; then
    gpasswd -a dovecot mail
    cp -rf $hestiacp/dovecot /etc/
    cp -f $hestiacp/logrotate/dovecot /etc/logrotate.d/
    chown -R root:root /etc/dovecot*
    if [ "$release" -eq 7 ]; then
        sed -i "s#namespace inbox {#namespace inbox {\n  inbox = yes#" /etc/dovecot/conf.d/15-mailboxes.conf
    fi
    chkconfig dovecot on
    service dovecot start
    check_result $? "dovecot start failed"
fi


#----------------------------------------------------------#
#                     Configure ClamAV                     #
#----------------------------------------------------------#

if [ "$clamd" = 'yes' ]; then
    useradd clam -s /sbin/nologin -d /var/lib/clamav 2>/dev/null
    gpasswd -a clam exim
    gpasswd -a clam mail
    cp -f $hestiacp/clamav/clamd.conf /etc/
    cp -f $hestiacp/clamav/freshclam.conf /etc/
    mkdir -p /var/log/clamav /var/run/clamav
    chown clam:clam /var/log/clamav /var/run/clamav
    chown -R clam:clam /var/lib/clamav
    if [ "$release" -ge '7' ]; then
        cp -f $hestiacp/clamav/clamd.service /usr/lib/systemd/system/
        systemctl --system daemon-reload
    fi
    /usr/bin/freshclam
    if [ "$release" -ge '7' ]; then
        sed -i "s/nofork/foreground/" /usr/lib/systemd/system/clamd.service
        systemctl daemon-reload
    fi
    chkconfig clamd on
    service clamd start
    #check_result $? "clamd start failed"
fi


#----------------------------------------------------------#
#                  Configure SpamAssassin                  #
#----------------------------------------------------------#

if [ "$spamd" = 'yes' ]; then
    chkconfig spamassassin on
    service spamassassin start
    check_result $? "spamassassin start failed"
    if [ "$release" -ge '7' ]; then
        groupadd -g 1001 spamd
        useradd -u 1001 -g spamd -s /sbin/nologin -d \
            /var/lib/spamassassin spamd
        mkdir /var/lib/spamassassin
        chown spamd:spamd /var/lib/spamassassin
    fi
fi


#----------------------------------------------------------#
#                   Configure RoundCube                    #
#----------------------------------------------------------#

if [ "$exim" = 'yes' ] && [ "$mysql" = 'yes' ]; then
    if [ "$apache" = 'yes' ]; then
        cp -f $hestiacp/roundcube/roundcubemail.conf /etc/httpd/conf.d/
    fi
    cp -f $hestiacp/roundcube/main.inc.php /etc/roundcubemail/config.inc.php
    cd /usr/share/roundcubemail/plugins/password
    cp -f $hestiacp/roundcube/hestia.php drivers/hestia.php
    cp -f $hestiacp/roundcube/config.inc.php config.inc.php
    sed -i "s/localhost/$servername/g" config.inc.php
    chmod a+r /etc/roundcubemail/*
    chmod -f 777 /var/log/roundcubemail
    r="$(gen_pass)"
    mysql -e "CREATE DATABASE roundcube"
    mysql -e "GRANT ALL ON roundcube.* TO 
            roundcube@localhost IDENTIFIED BY '$r'"
    sed -i "s/%password%/$r/g" /etc/roundcubemail/config.inc.php
    chmod 640 /etc/roundcubemail/config.inc.php
    chown root:apache /etc/roundcubemail/config.inc.php
    if [ -e "/usr/share/roundcubemail/SQL/mysql.initial.sql" ]; then
        mysql roundcube < /usr/share/roundcubemail/SQL/mysql.initial.sql
    else
        mysql roundcube < /usr/share/doc/roundcubemail-*/SQL/mysql.initial.sql
    fi
fi


#----------------------------------------------------------#
#                    Configure Fail2Ban                    #
#----------------------------------------------------------#

if [ "$fail2ban" = 'yes' ]; then
    echo "(*) Configuring fail2ban access monitor..."
    cp -rf $HESTIA_INSTALL_DIR/fail2ban /etc/
    if [ "$dovecot" = 'no' ]; then
        fline=$(cat /etc/fail2ban/jail.local |grep -n dovecot-iptables -A 2)
        fline=$(echo "$fline" |grep enabled |tail -n1 |cut -f 1 -d -)
        sed -i "${fline}s/true/false/" /etc/fail2ban/jail.local
    fi
    if [ "$exim" = 'no' ]; then
        fline=$(cat /etc/fail2ban/jail.local |grep -n exim-iptables -A 2)
        fline=$(echo "$fline" |grep enabled |tail -n1 |cut -f 1 -d -)
        sed -i "${fline}s/true/false/" /etc/fail2ban/jail.local
    fi
    if [ "$vsftpd" = 'yes' ]; then
        #Create vsftpd Log File
        if [ ! -f "/var/log/vsftpd.log" ]; then
            touch /var/log/vsftpd.log
        fi
        fline=$(cat /etc/fail2ban/jail.local |grep -n vsftpd-iptables -A 2)
        fline=$(echo "$fline" |grep enabled |tail -n1 |cut -f 1 -d -)
        sed -i "${fline}s/false/true/" /etc/fail2ban/jail.local
    fi
    chkconfig fail2ban on
    mkdir -p /var/run/fail2ban
    if [ -e "/usr/lib/systemd/system/fail2ban.service" ]; then
        exec_pre='ExecStartPre=/bin/mkdir -p /var/run/fail2ban'
        sed -i "s|\[Service\]|[Service]\n$exec_pre|g" \
            /usr/lib/systemd/system/fail2ban.service
        systemctl daemon-reload
    fi
    service fail2ban start
    check_result $? "fail2ban start failed"
fi


#----------------------------------------------------------#
#                       Configure API                      #
#----------------------------------------------------------#

if [ "$api" = 'yes' ]; then
    echo "API='yes'" >> $HESTIA/conf/hestia.conf
else
    rm -r $HESTIA/web/api
    echo "API='no'" >> $HESTIA/conf/hestia.conf
fi


#----------------------------------------------------------#
#                      Fix phpmyadmin                      #
#----------------------------------------------------------#
# Special thanks to Pavel Galkin (https://skurudo.ru)
# https://github.com/skurudo/phpmyadmin-fixer

if [ "$mysql" = 'yes' ]; then
    source $HESTIA_INSTALL_DIR/phpmyadmin/pma.sh > /dev/null 2>&1
fi


#----------------------------------------------------------#
#                   Configure Admin User                   #
#----------------------------------------------------------#

# Deleting old admin user
if [ ! -z "$(grep ^admin: /etc/passwd)" ] && [ "$force" = 'yes' ]; then
    chattr -i /home/admin/conf > /dev/null 2>&1
    userdel -f admin > /dev/null 2>&1
    chattr -i /home/admin/conf > /dev/null 2>&1
    mv -f /home/admin  $hst_backups/home/ > /dev/null 2>&1
    rm -f /tmp/sess_* > /dev/null 2>&1
fi
if [ ! -z "$(grep ^admin: /etc/group)" ] && [ "$force" = 'yes' ]; then
    groupdel admin > /dev/null 2>&1
fi

# Enable sftp jail
$HESTIA/bin/v-add-sys-sftp-jail > /dev/null 2>&1
check_result $? "can't enable sftp jail"

# Adding Hestia admin account
$HESTIA/bin/v-add-user admin $vpass $email default System Administrator
check_result $? "can't create admin user"
$HESTIA/bin/v-change-user-shell admin nologin
$HESTIA/bin/v-change-user-language admin $lang

# Configuring system IPs
$HESTIA/bin/v-update-sys-ip > /dev/null 2>&1

# Get main IP
ip=$(ip addr|grep 'inet '|grep global|head -n1|awk '{print $2}'|cut -f1 -d/)

# Configuring firewall
if [ "$iptables" = 'yes' ]; then
    $HESTIA/bin/v-update-firewall
fi

# Get public IP
pub_ip=$(curl --ipv4 -s https://ip.hestiacp.com/)
if [ ! -z "$pub_ip" ] && [ "$pub_ip" != "$ip" ]; then
    if [ -e /etc/rc.local ]; then
        sed -i '/exit 0/d' /etc/rc.local
    fi
    echo "$HESTIA/bin/v-update-sys-ip" >> /etc/rc.local
    echo "exit 0" >> /etc/rc.local
    chmod +x /etc/rc.local
    systemctl enable rc-local
    $HESTIA/bin/v-change-sys-ip-nat $ip $pub_ip > /dev/null 2>&1
    ip=$pub_ip
fi

# Configuring MySQL/MariaDB host
if [ "$mysql" = 'yes' ]; then
    $HESTIA/bin/v-add-database-host mysql localhost root $mpass
fi

# Configuring PostgreSQL host
if [ "$postgresql" = 'yes' ]; then
    $HESTIA/bin/v-add-database-host pgsql localhost postgres $ppass
fi

# Adding default domain
$HESTIA/bin/v-add-web-domain admin $servername
check_result $? "can't create $servername domain"

# Adding cron jobs
export SCHEDULED_RESTART="yes"
command="sudo $HESTIA/bin/v-update-sys-queue restart"
$HESTIA/bin/v-add-cron-job 'admin' '*/2' '*' '*' '*' '*' "$command"
systemctl restart cron

command="sudo $HESTIA/bin/v-update-sys-queue disk"
$HESTIA/bin/v-add-cron-job 'admin' '15' '02' '*' '*' '*' "$command"
command="sudo $HESTIA/bin/v-update-sys-queue traffic"
$HESTIA/bin/v-add-cron-job 'admin' '10' '00' '*' '*' '*' "$command"
command="sudo $HESTIA/bin/v-update-sys-queue webstats"
$HESTIA/bin/v-add-cron-job 'admin' '30' '03' '*' '*' '*' "$command"
command="sudo $HESTIA/bin/v-update-sys-queue backup"
$HESTIA/bin/v-add-cron-job 'admin' '*/5' '*' '*' '*' '*' "$command"
command="sudo $HESTIA/bin/v-backup-users"
$HESTIA/bin/v-add-cron-job 'admin' '10' '05' '*' '*' '*' "$command"
command="sudo $HESTIA/bin/v-update-user-stats"
$HESTIA/bin/v-add-cron-job 'admin' '20' '00' '*' '*' '*' "$command"
command="sudo $HESTIA/bin/v-update-sys-rrd"
$HESTIA/bin/v-add-cron-job 'admin' '*/5' '*' '*' '*' '*' "$command"

# Enable automatic updates
$HESTIA/bin/v-add-cron-hestia-autoupdate

# Building initital rrd images
$HESTIA/bin/v-update-sys-rrd

# Enabling file system quota
if [ "$quota" = 'yes' ]; then
    $HESTIA/bin/v-add-sys-quota
fi

# Set backend port
$HESTIA/bin/v-change-sys-port $port

# Set default theme
$HESTIA/bin/v-change-sys-theme 'default'

# Starting Hestia service
chkconfig hestia on
service hestia start
check_result $? "hestia start failed"
chown admin:admin $HESTIA/data/sessions

# Adding notifications
$HESTIA/upd/add_notifications.sh

# Adding cronjob for autoupdates
$HESTIA/bin/v-add-cron-hestia-autoupdate


#----------------------------------------------------------#
#                   Hestia Access Info                     #
#----------------------------------------------------------#

# Comparing hostname and IP
host_ip=$(host $servername| head -n 1 |awk '{print $NF}')
if [ "$host_ip" = "$ip" ]; then
    ip="$servername"
fi

echo -e "\n"
echo "===================================================================="
echo -e "\n"

# Sending notification to admin email
echo -e "Congratulations!

You have successfully installed Hestia Control Panel on your server.

Ready to get started? Log in using the following credentials:

    Admin URL:  https://$ip:$port
    Username:   admin
    Password:   $vpass

Thank you for choosing Hestia Control Panel to power your full stack web server,
we hope that you enjoy using it as much as we do!

Please feel free to contact us at any time if you have any questions,
or if you encounter any bugs or problems:

E-mail:  info@hestiacp.com
Web:     https://www.hestiacp.com/
Forum:   https://forum.hestiacp.com/
GitHub:  https://www.github.com/hestiacp/hestiacp

Note: Automatic updates are enabled by default. If you would like to disable them,
please log in and navigate to Server > Updates to turn them off.

Help support the Hestia Contol Panel project by donating via PayPal:
https://www.hestiacp.com/donate
--
Sincerely yours,
The Hestia Control Panel development team

Made with love & pride by the open-source community around the world.
" > $tmpfile

send_mail="$HESTIA/web/inc/mail-wrapper.php"
cat $tmpfile | $send_mail -s "Hestia Control Panel" $email

# Congrats
echo
cat $tmpfile
rm -f $tmpfile

# Add welcome message to notification panel
$HESTIA/bin/v-add-user-notification admin 'Welcome!' 'For more information on how to use Hestia Control Panel, click on the Help icon in the top right corner of the toolbar.<br><br>Please report any bugs or issues on GitHub at<br>https://github.com/hestiacp/hestiacp/issues<br><br>Have a great day!'

echo "(!) IMPORTANT: You must logout or restart the server before continuing."
echo ""
if [ "$interactive" = 'yes' ]; then
    echo -n " Do you want to reboot now? [Y/N] "
    read reboot

    if [ "$reboot" = "Y" ] || [ "$reboot" = "y" ]; then
        reboot
    fi
fi

# EOF