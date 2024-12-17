#!/bin/bash

sleep 1-
sudo apt update

sleep 10
sudo apt install -y nginx

sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup

sudo bash -c \"cat > /etc/nginx/nginx.conf <<EOL
events { }
http {
    server {
        listen 80 proxy_protocol;
        location / {
            add_header Content-Type text/html;
            return 200 '<html><body>server_addr=\$server_addr<br>remote_addr=\$remote_addr<br>x_forwarded_for=\$proxy_add_x_forwarded_for<br>proxy_protocol_addr=\$proxy_protocol_addr</body></html>';
        }
    }
}
EOL\"

sudo systemctl restart nginx
