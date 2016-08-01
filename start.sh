#!/bin/sh
#########################################################################
# File Name: start.sh
# Author: Skiychan
# Email:  dev@skiy.net
# Version:
# Created Time: 2015/12/13
#########################################################################
Nginx_Install_Dir=/usr/local/nginx
DATA_DIR=/data/www

set -e
chown -R www.www $DATA_DIR

# HTTPS
if [[ -n "$PROXY_WEB" ]]; then

    # CONF file
    [ -f "${Nginx_Install_Dir}/conf/vhost" ] || mkdir -p $Nginx_Install_Dir/conf/vhost
    if [ -z "$PROXY_DOMAIN" ]; then
            echo >&2 'error:  missing PROXY_DOMAIN'
            echo >&2 '  Did you forget to add -e PROXY_DOMAIN=... ?'
            exit 1
    fi

    # FREE HTTPS
    if [[ -n "$PROXY_FREE" ]]; then

        #Let's FREE HTTPS
        curl -O -SL -C - https://github.com/certbot/certbot/archive/v0.8.1.tar.gz  && \
        tar -zxvf v0.8.1.tar.gz && \
        cd certbot-0.8.1
        ./certbot-auto certonly --email dev@skiy.net --agree-tos --webroot -w /data/www -d $PROXY_DOMAIN
        CRT_PATH=/etc/letsencrypt/live/{$PROXY_DOMAIN}/fullchain.pem;
        KEY_PATH=/etc/letsencrypt/live/{$PROXY_DOMAIN}/privkey.pem;

    else    

        if [ -z "$PROXY_CRT" ]; then
             echo >&2 'error:  missing PROXY_CRT'
             echo >&2 '  Did you forget to add -e PROXY_CRT=... ?'
             exit 1
         fi

         if [ -z "$PROXY_KEY" ]; then
                 echo >&2 'error:  missing PROXY_KEY'
                 echo >&2 '  Did you forget to add -e PROXY_KEY=... ?'
                 exit 1
         fi

         if [ ! -f "${Nginx_Install_Dir}/conf/ssl/${PROXY_CRT}" ]; then
                 echo >&2 'error:  missing PROXY_CRT'
                 echo >&2 "  You need to put ${PROXY_CRT} in ssl directory"
                 exit 1
         fi

         if [ ! -f "${Nginx_Install_Dir}/conf/ssl/${PROXY_KEY}" ]; then
                 echo >&2 'error:  missing PROXY_CSR'
                 echo >&2 "  You need to put ${PROXY_KEY} in ssl directory"
                 exit 1
         fi

         [ -f "${Nginx_Install_Dir}/conf/ssl" ] || mkdir -p $Nginx_Install_Dir/conf/ssl
         CRT_PATH=ssl/${PROXY_CRT}
         KEY_PATH=ssl/${PROXY_KEY}

     fi    

    cat > ${Nginx_Install_Dir}/conf/vhost/website.conf << EOF
server {
    listen 80;
    server_name $PROXY_DOMAIN;
    return 301 https://$PROXY_DOMAIN\$request_uri;
    }

server {
    listen 443 ssl;
    server_name $PROXY_DOMAIN;

    ssl on;
    ssl_certificate ${CRT_PATH};
    ssl_certificate_key ${KEY_PATH};
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";
    keepalive_timeout 70;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    root   $DATA_DIR;
    index  index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        root           /data/www;
        fastcgi_pass   127.0.0.1:9000;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME  /\$document_root\$fastcgi_script_name;
        include        fastcgi_params;
    }
}
EOF
fi

/usr/bin/supervisord -n -c /etc/supervisord.conf
