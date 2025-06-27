#



## SSL init

Generate Diffie-Hellman keys by running this command on your server:
openssl dhparam -out /etc/nginx/dhparam.pem 2048

Create a common ACME-challenge directory (for Let's Encrypt):
mkdir -p /var/www/_letsencrypt
chown nginx /var/www/_letsencrypt

## Certbot

Comment out SSL related directives in the configuration:

sed -i -r 's/(listen .*443)/\1; #/g; s/(ssl_(certificate|certificate_key|trusted_certificate) )/#;#\1/g; s/(server \{)/\1\n    ssl off;/g' /etc/nginx/sites-available/ipv6.fail.conf /etc/nginx/sites-available/example.com.conf
This command will add a temporary ssl off directive to ensure that SSL directives are not active. This may cause NGINX to emit a warning, which is safe to ignore. The directive will be removed once Certbot is configured.

Reload your NGINX server:

sudo nginx -t && sudo systemctl reload nginx
Obtain SSL certificates from Let's Encrypt using Certbot:

certbot certonly --webroot -d ipv6.fail -d www.ipv6.fail --email haugen.lasse@gmail.com -w /var/www/_letsencrypt -n --agree-tos --force-renewal
certbot certonly --webroot -d example.com --email info@example.com -w /var/www/_letsencrypt -n --agree-tos --force-renewal
Uncomment SSL related directives in the configuration:

sed -i -r -z 's/#?; ?#//g; s/(server \{)\n    ssl off;/\1/g' /etc/nginx/sites-available/ipv6.fail.conf /etc/nginx/sites-available/example.com.conf
Reload your NGINX server:

sudo nginx -t && sudo systemctl reload nginx
Configure Certbot to reload NGINX when it successfully renews certificates:

echo -e '#!/bin/bash\nnginx -t && systemctl reload nginx' | sudo tee /etc/letsencrypt/renewal-hooks/post/nginx-reload.sh
sudo chmod a+x /etc/letsencrypt/renewal-hooks/post/nginx-reload.sh
