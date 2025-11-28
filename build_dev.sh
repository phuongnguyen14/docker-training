#!/bin/bash

# Script để deploy lên Render
# Usage: ./build_dev.sh

echo "🚀 Starting deployment to Render..."

# 1. Push code lên GitHub
echo "📤 Pushing code to GitHub..."
git add .
git commit -m "Deploy: $(date +%Y-%m-%d_%H:%M:%S)"
git push origin feature/docker_train

# 2. Trigger Render deployment via API
echo "🔨 Triggering Render deployment..."

# Lấy API key từ Render Dashboard → Account Settings → API Keys
RENDER_API_KEY="rnd_mA0bxEe3rVwfYiHS7tW2IqEb0Ysh"
SERVICE_ID="srv-d4kii10gjchc73a6ottg"

# Trigger manual deploy
curl -X POST "https://api.render.com/v1/services/${SERVICE_ID}/deploys" \
  -H "Authorization: Bearer ${RENDER_API_KEY}" \
  -H "Content-Type: application/json"

echo "✅ Deployment triggered!"
echo "📊 Check status at: https://dashboard.render.com"