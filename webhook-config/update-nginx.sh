#!/bin/bash

# Script to update nginx configuration for webhook proxy
# This requires sudo access

echo "This script will update the nginx configuration for clidecoder.com"
echo "to proxy /hooks requests to the webhook service on port 9000"
echo ""

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run this script with sudo:"
    echo "sudo ./update-nginx.sh"
    exit 1
fi

# Backup current configuration
echo "Creating backup of current nginx configuration..."
cp /etc/nginx/sites-available/clidecoder.com /etc/nginx/sites-available/clidecoder.com.backup-$(date +%Y%m%d-%H%M%S)

# Create new configuration
cat > /tmp/clidecoder.com.new << 'EOF'
server {
    server_name clidecoder.com www.clidecoder.com;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /hooks {
        proxy_pass http://localhost:9000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Preserve GitHub webhook headers
        proxy_set_header X-GitHub-Event $http_x_github_event;
        proxy_set_header X-GitHub-Delivery $http_x_github_delivery;
        proxy_set_header X-Hub-Signature $http_x_hub_signature;
        proxy_set_header X-Hub-Signature-256 $http_x_hub_signature_256;
        
        # Increase timeout for webhook processing
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }

    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/clidecoder.com/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/clidecoder.com/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

}
server {
    if ($host = clidecoder.com) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


    listen 80;
    server_name clidecoder.com www.clidecoder.com;
    return 404; # managed by Certbot


}
EOF

# Copy new configuration
echo "Updating nginx configuration..."
cp /tmp/clidecoder.com.new /etc/nginx/sites-available/clidecoder.com

# Test nginx configuration
echo "Testing nginx configuration..."
nginx -t

if [ $? -eq 0 ]; then
    echo "Configuration test passed!"
    echo "Reloading nginx..."
    systemctl reload nginx
    echo ""
    echo "✓ Nginx configuration updated successfully!"
    echo ""
    echo "Your webhook endpoint is now available at:"
    echo "https://clidecoder.com/hooks/github-webhook"
    echo ""
    echo "Update your GitHub webhook URL to use this endpoint."
else
    echo "Configuration test failed!"
    echo "Restoring backup..."
    cp /etc/nginx/sites-available/clidecoder.com.backup-$(date +%Y%m%d-%H%M%S) /etc/nginx/sites-available/clidecoder.com
    echo "Backup restored. Please check the configuration manually."
    exit 1
fi

# Clean up
rm -f /tmp/clidecoder.com.new