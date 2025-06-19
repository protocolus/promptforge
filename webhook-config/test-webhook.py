#!/usr/bin/env python3

import hmac
import hashlib
import json
import requests
import sys

# Read the secret from hooks.json
with open('hooks.json', 'r') as f:
    config = json.load(f)
    secret = config[0]['trigger-rule']['match']['secret']

# Test payload
payload = {
    "action": "opened",
    "repository": {
        "full_name": "protocolus/promptforge",
        "name": "promptforge",
        "owner": {
            "login": "protocolus"
        }
    },
    "sender": {
        "login": "test-user"
    },
    "issue": {
        "number": 999,
        "title": "Test Issue from Webhook",
        "user": {
            "login": "test-user"
        }
    }
}

# Convert payload to JSON
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
    'X-GitHub-Event': 'issues',
    'X-Hub-Signature-256': f'sha256={signature}',
    'X-GitHub-Delivery': '12345678-1234-1234-1234-123456789012'
}

# Send request
url = 'http://localhost:9000/hooks/github-webhook'
print(f"Sending test webhook to {url}")
print(f"Event type: issues")
print(f"Action: opened")

try:
    response = requests.post(url, data=payload_json, headers=headers)
    print(f"\nResponse status: {response.status_code}")
    print(f"Response body: {response.text}")
    
    if response.status_code == 200:
        print("\n✓ Webhook test successful! Check logs at:")
        print("  webhook-config/logs/github-events-*.log")
except Exception as e:
    print(f"\nError: {e}")
    sys.exit(1)