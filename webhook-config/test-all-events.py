#!/usr/bin/env python3

import hmac
import hashlib
import json
import requests
import time
from datetime import datetime

# Read the secret from hooks.json
with open('hooks.json', 'r') as f:
    config = json.load(f)
    secret = config[0]['trigger-rule']['match']['secret']

def send_webhook(event_type, payload):
    """Send a webhook with proper GitHub signature"""
    payload_json = json.dumps(payload)
    
    # Calculate HMAC SHA256 signature
    signature = hmac.new(
        secret.encode('utf-8'),
        payload_json.encode('utf-8'),
        hashlib.sha256
    ).hexdigest()
    
    # Headers
    headers = {
        'Content-Type': 'application/json',
        'X-GitHub-Event': event_type,
        'X-Hub-Signature-256': f'sha256={signature}',
        'X-GitHub-Delivery': f'{datetime.now().timestamp()}'
    }
    
    # Send request
    url = 'http://localhost:9000/hooks/github-webhook'
    response = requests.post(url, data=payload_json, headers=headers)
    
    print(f"[{event_type}] Status: {response.status_code}")
    return response.status_code == 200

# Test different event types
print("Testing GitHub Webhook with various events")
print("==========================================\n")

# 1. Push event
print("1. Testing PUSH event...")
push_payload = {
    "ref": "refs/heads/main",
    "commits": [
        {
            "id": "abc123def456",
            "message": "Test commit from webhook",
            "author": {"name": "Test User", "email": "test@example.com"}
        }
    ],
    "repository": {
        "full_name": "protocolus/promptforge",
        "name": "promptforge"
    },
    "pusher": {"name": "test-user"}
}
send_webhook("push", push_payload)
time.sleep(0.5)

# 2. Pull Request event
print("\n2. Testing PULL_REQUEST event...")
pr_payload = {
    "action": "opened",
    "pull_request": {
        "number": 42,
        "title": "Add awesome feature",
        "user": {"login": "contributor"},
        "state": "open"
    },
    "repository": {"full_name": "protocolus/promptforge"}
}
send_webhook("pull_request", pr_payload)
time.sleep(0.5)

# 3. Issue event
print("\n3. Testing ISSUES event...")
issue_payload = {
    "action": "closed",
    "issue": {
        "number": 123,
        "title": "Bug in webhook handler",
        "user": {"login": "bug-reporter"}
    },
    "repository": {"full_name": "protocolus/promptforge"}
}
send_webhook("issues", issue_payload)
time.sleep(0.5)

# 4. Release event
print("\n4. Testing RELEASE event...")
release_payload = {
    "action": "published",
    "release": {
        "tag_name": "v1.0.0",
        "name": "First Stable Release",
        "prerelease": False
    },
    "repository": {"full_name": "protocolus/promptforge"}
}
send_webhook("release", release_payload)
time.sleep(0.5)

# 5. Workflow run event
print("\n5. Testing WORKFLOW_RUN event...")
workflow_payload = {
    "action": "completed",
    "workflow_run": {
        "name": "CI/CD Pipeline",
        "status": "completed",
        "conclusion": "success",
        "run_number": 123
    },
    "repository": {"full_name": "protocolus/promptforge"}
}
send_webhook("workflow_run", workflow_payload)

print("\n✓ All webhook tests completed!")
print("\nCheck the logs at: webhook-config/logs/github-events-*.log")