#!/bin/bash

# Automatically provisions an Ubuntu 14.04 VM(64-bit)

# Make vagrant user login as root right away because sometimes we just want to get shit done, you can ctrl+d or su back to vagrant if you want
#echo 'sudo -i -u root' > /home/vagrant/.bash_profile

# Change hostname to something more... reasonable
hostname 'ubuntu-development'
# Because the above is only temprary
cat /dev/null > /etc/hostname
echo 'ubuntu-developemnt' > /etc/hostname

# Seriously, advertisements in a damn OS? Be gone!
echo '[sysinfo]' > /etc/landscape/client.conf
echo 'exclude_sysinfo_plugins = LandscapeLink' > /etc/landscape/client.conf
rm -rf /etc/update-motd.d/10-help-text
rm -rf /etc/update-motd.d/98-cloudguest
rm -rf /etc/update-motd.d/51-cloudguest

# Install our much needed software stack
#
# These things causes issues with virtualbox(breaking shared folders, etc.) so we'll leave these out for now
# apt-get update
# apt-get upgrade -y
# apt-get install -y build-essential dkms

# Will install the following: CURL, Git, Nginx, HTop, Screen, Nano, Node, NPM, MySQL(Percona drop-in replacement) and PHP(apc, curl, fpm, gd, json, mcrypt, sqlite, mysql, pear)
DEBIAN_FRONTEND=noninteractive aptitude install -q -y build-essential git curl nginx htop screen nano nodejs npm libmcrypt-dev percona-xtradb-cluster-server-5.5 php5 php5-dev php5-apcu php5-curl php5-fpm php5-gd php5-json php5-mcrypt php5-sqlite php5-mysql php-pear

# Because PHP fails to recognize mcrypt... grrr
ln -s /etc/php5/conf.d/mcrypt.ini /etc/php5/mods-available
php5enmod mcrypt

# Why in the FUCK is the nodejs package installed as nodejs... ah nvm who cares
ln -s /usr/bin/nodejs /usr/bin/node

# Setup our projects directory that we'll share with our local machine
mkdir -p /home/vagrant/www
chown www-data:www-data /home/vagrant/www

# Install composer. Use it! That's an order!
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/bin/composer

# Change user in php5-fpm pool to vagrant so we actually have permission for stuff
#sed -i 's/www-data/vagrant/g' /etc/php5/fpm/pool.d/www.conf

# Turn sendfile off in Nginx for vagrant
sed -i 's/sendfile on/sendfile off/g' /etc/nginx/nginx.conf

# Setup a default Nginx site running PHP
cat /dev/null > /etc/nginx/sites-available/default
cat > /etc/nginx/sites-available/default <<EOL
server {
    listen 80 default_server;
    server_name localhost;
    root /home/vagrant/www/;
    index index.php index.html;
    access_log  /var/log/nginx/default.access.log;
    error_log  /var/log/nginx/default.error.log notice;

    location ~* ^.+.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt)\$ {
        expires max;
    }

    location ~* \.php\$ {
        fastcgi_index index.php;
        fastcgi_split_path_info ^(.+\.php)(.*)\\$;
        fastcgi_pass unix:/var/run/php5-fpm.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param SCRIPT_NAME \$fastcgi_script_name;
    }

    location / {
        try_files \$uri \$uri/ /index.php\$query_string;
        autoindex on;
    }

    location ~ ^/(?<dir>[^/]+) {
        try_files \$uri /\$dir/index.php\$query_string;
    }

    location ~ /\. {
        deny  all;
    }
}
EOL

# Add convenience aliases for root
cat > /home/vagrant/.bash_aliases <<EOL
# Easier navigation: .., ..., ...., ....., ~ and -
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ~="cd ~" # `cd` is probably faster to type though
alias -- -="cd -"

# Shortcuts
alias p="cd /home/vagrant/www/"
alias g="git"
alias h="history"

# Detect which `ls` flavor is in use
if ls --color > /dev/null 2>&1; then # GNU `ls`
        colorflag="--color"
else # OS X `ls`
        colorflag="-G"
fi

# List all files colorized in long format
alias ls='ls -aFHhlLo \${colorflag}'
alias l="ls"

# Always use color output for `ls`
export LS_COLORS='no=00:fi=00:di=01;34:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.avi=01;35:*.fli=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.ogg=01;35:*.mp3=01;35:*.wav=01;35:'

# Enable aliases to be sudo’ed
alias sudo='sudo '

# Reload the shell (i.e. invoke as a login shell)
alias reload="exec \$SHELL -l"
EOL

# Restart the services we just provisioned
service php5-fpm restart
service nginx restart