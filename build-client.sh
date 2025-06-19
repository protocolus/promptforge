#!/bin/bash

echo "Building React client..."
cd /home/clide/promptforge/client

# Run the build with timeout
timeout 300 npm run build

if [ $? -eq 0 ]; then
    echo "✅ Client build completed successfully!"
    
    # Restart PM2 to serve the new build
    cd /home/clide/promptforge
    pm2 restart promptforge
    echo "✅ Server restarted with new build"
else
    echo "⚠️ Build timed out or failed, but basic site is still running"
fi