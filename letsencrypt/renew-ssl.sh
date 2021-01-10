#!/bin/bash

# Configuration
web_service='nginx' # name of service to reload
reload_web=false # Should the web_service be reloaded?_
le_path='/opt/letsencrypt' # Path to let's encrypt
config_path='/etc/nginx/letsencrypt/ssl-enabled/' #Path to LE configuration ini files
exp_limit=30; #Threshold of days before your cert expires, will renew if under this threshold

#vars
count=0;

for config_file in $config_path*.ini; do
        if [ -f "$config_file" ]; then
                echo "Analyzing file: $config_file"
                domain=`grep "^\s*domains" $config_file | sed "s/^\s*domains\s*=\s*//" | sed 's/(\s*)\|,.*$//'`
                cert_file="/etc/letsencrypt/live/$domain/fullchain.pem"

                if [ ! -f $cert_file ]; then
                        echo "[ERROR] certificate file not found for domain $domain."
                fi

                exp=$(date -d "`openssl x509 -in $cert_file -text -noout|grep "Not After"|cut -c 25-`" +%s)
                datenow=$(date -d "now" +%s)
                days_exp=$(echo \( $exp - $datenow \) / 86400 |bc)

                echo "Checking expiration date for $domain..."

                if [ "$days_exp" -gt "$exp_limit" ] ; then
                        echo "The certificate is up to date, no need for renewal ($days_exp days left)."
                else
                        echo "The certificate for $domain is about to expire soon. Starting webroot renewal script..."
                        $le_path/letsencrypt-auto certonly -a webroot --agree-tos --renew-by-default --config $config_file
                        echo "Renewal process finished for domain $domain"
                        count++;
                fi
        fi
done

if [ $count -gt 0 -a $reload_web = true ]; then
        echo "Reloading $web_service"
        /usr/sbin/service $web_service reload
        echo "Renewal process finished, $web_service reloaded"
else
        echo "Renewal process finished, $web_service not reloaded"
fi
