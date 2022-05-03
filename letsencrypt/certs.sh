#!/bin/bash
systemctl stop nginx
certbot certonly --standalone -d example.com -d api.example.com
systemctl start nginx
systemctl status nginx
