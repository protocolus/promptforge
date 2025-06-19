#!/bin/bash

# Start script for GitHub Webhook Handler

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Starting GitHub Webhook Handler${NC}"

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}Warning: .env file not found. Copy .env.example to .env and configure it.${NC}"
    if [ ! -f .env.example ]; then
        echo -e "${RED}Error: .env.example not found${NC}"
        exit 1
    fi
    echo "Copying .env.example to .env..."
    cp .env.example .env
    echo -e "${YELLOW}Please edit .env file with your credentials before running again.${NC}"
    exit 1
fi

# Load environment variables
set -a
source .env
set +a

# Check required environment variables
required_vars=("GITHUB_TOKEN" "GITHUB_WEBHOOK_SECRET" "ANTHROPIC_API_KEY")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}Error: $var is not set in .env file${NC}"
        exit 1
    fi
done

echo -e "${GREEN}✓${NC} Environment variables loaded"

# Create directories
mkdir -p logs outputs/{issues,pull_requests,reviews,workflows}
echo -e "${GREEN}✓${NC} Directories created"

# Check if Docker is available
if command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}Starting with Docker Compose...${NC}"
    docker-compose up -d
    echo -e "${GREEN}✓${NC} Webhook handler started with Docker"
    echo "View logs with: docker-compose logs -f"
    echo "Check health: curl http://localhost:9000/health"
elif command -v docker &> /dev/null; then
    echo -e "${GREEN}Starting with Docker...${NC}"
    docker build -t github-webhook-handler .
    docker run -d \
        --name github-webhook-handler \
        -p 9000:9000 \
        -e GITHUB_TOKEN="$GITHUB_TOKEN" \
        -e GITHUB_WEBHOOK_SECRET="$GITHUB_WEBHOOK_SECRET" \
        -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
        -v "$(pwd)/config:/app/config:ro" \
        -v "$(pwd)/prompts:/app/prompts:ro" \
        -v "$(pwd)/logs:/app/logs" \
        -v "$(pwd)/outputs:/app/outputs" \
        --restart unless-stopped \
        github-webhook-handler
    echo -e "${GREEN}✓${NC} Webhook handler started with Docker"
    echo "View logs with: docker logs -f github-webhook-handler"
    echo "Check health: curl http://localhost:9000/health"
else
    echo -e "${GREEN}Starting with Python directly...${NC}"
    
    # Check if virtual environment exists
    if [ ! -d "venv" ]; then
        echo "Creating virtual environment..."
        python3 -m venv venv
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Install dependencies
    echo "Installing dependencies..."
    pip install -r requirements.txt
    
    # Set Python path
    export PYTHONPATH="${PWD}/src:${PYTHONPATH}"
    
    # Start the application
    echo -e "${GREEN}Starting webhook handler...${NC}"
    python -m uvicorn webhook_handler.main:app --host 0.0.0.0 --port 9000 &
    
    # Save PID
    echo $! > webhook_handler.pid
    echo -e "${GREEN}✓${NC} Webhook handler started (PID: $!)"
    echo "Check health: curl http://localhost:9000/health"
    echo "Stop with: ./scripts/stop.sh"
fi

echo ""
echo -e "${GREEN}GitHub Webhook Handler is now running!${NC}"
echo ""
echo "Next steps:"
echo "1. Configure your GitHub repository webhook to point to: http://your-server:9000/github-webhook"
echo "2. Test with: curl http://localhost:9000/health"
echo "3. View stats at: http://localhost:9000/stats"