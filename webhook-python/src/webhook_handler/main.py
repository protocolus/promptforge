"""Main FastAPI application for GitHub webhook handling."""

import hashlib
import hmac
import uuid
from typing import Dict, Any

from fastapi import FastAPI, Request, HTTPException, BackgroundTasks
from fastapi.responses import JSONResponse

from .config import Settings
from .logging_config import setup_logging, get_logger, request_id_processor
from .webhook_processor import WebhookProcessor


# Load configuration
settings = Settings.from_yaml("config/settings.yaml")

# Setup logging
setup_logging(settings.logging)
logger = get_logger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="GitHub Webhook Handler",
    description="Handles GitHub webhooks with Claude Code integration",
    version="1.0.0"
)

# Initialize webhook processor
webhook_processor = WebhookProcessor(settings)


def verify_signature(payload: bytes, signature: str) -> bool:
    """Verify GitHub webhook signature."""
    if not settings.features.signature_validation:
        return True
    
    if not signature:
        return False
    
    # Remove 'sha256=' prefix
    if signature.startswith('sha256='):
        signature = signature[7:]
    
    # Calculate expected signature
    expected = hmac.new(
        settings.github.webhook_secret.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(expected, signature)


@app.get("/health")
async def health_check() -> Dict[str, str]:
    """Health check endpoint."""
    return {"status": "healthy", "service": "github-webhook-handler"}


@app.post(settings.server.webhook_path)
async def handle_webhook(
    request: Request,
    background_tasks: BackgroundTasks
) -> JSONResponse:
    """Handle incoming GitHub webhooks."""
    
    # Generate request ID for tracking
    request_id = str(uuid.uuid4())
    request_id_processor.set_request_id(request_id)
    
    logger.info("Webhook received", request_id=request_id)
    
    try:
        # Get headers
        event_type = request.headers.get("X-GitHub-Event")
        delivery_id = request.headers.get("X-GitHub-Delivery")
        signature = request.headers.get("X-Hub-Signature-256")
        
        if not event_type:
            raise HTTPException(status_code=400, detail="Missing X-GitHub-Event header")
        
        # Get payload
        payload_bytes = await request.body()
        
        # Verify signature
        if not verify_signature(payload_bytes, signature):
            logger.error("Invalid webhook signature", request_id=request_id)
            raise HTTPException(status_code=401, detail="Invalid signature")
        
        # Parse JSON payload
        try:
            payload = await request.json()
        except Exception as e:
            logger.error("Invalid JSON payload", error=str(e), request_id=request_id)
            raise HTTPException(status_code=400, detail="Invalid JSON payload")
        
        # Extract repository information
        repository = payload.get("repository", {})
        repo_name = repository.get("full_name")
        
        if not repo_name:
            logger.warning("No repository information in payload", request_id=request_id)
            return JSONResponse({"status": "ignored", "reason": "no repository"})
        
        # Check if repository is configured
        if not settings.get_repository_config(repo_name):
            logger.info(
                "Repository not configured", 
                repository=repo_name,
                request_id=request_id
            )
            return JSONResponse({"status": "ignored", "reason": "repository not configured"})
        
        # Check if event type is enabled
        if not settings.is_event_enabled(repo_name, event_type):
            logger.info(
                "Event type not enabled",
                event_type=event_type,
                repository=repo_name,
                request_id=request_id
            )
            return JSONResponse({"status": "ignored", "reason": "event type not enabled"})
        
        # Process webhook in background
        if settings.features.async_processing:
            background_tasks.add_task(
                webhook_processor.process_webhook,
                event_type=event_type,
                payload=payload,
                delivery_id=delivery_id,
                request_id=request_id
            )
            
            logger.info(
                "Webhook queued for processing",
                event_type=event_type,
                repository=repo_name,
                request_id=request_id
            )
            
            return JSONResponse({
                "status": "queued",
                "request_id": request_id,
                "event_type": event_type,
                "repository": repo_name
            })
        else:
            # Process synchronously
            result = await webhook_processor.process_webhook(
                event_type=event_type,
                payload=payload,
                delivery_id=delivery_id,
                request_id=request_id
            )
            
            return JSONResponse({
                "status": "processed",
                "request_id": request_id,
                "result": result
            })
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(
            "Unexpected error processing webhook",
            error=str(e),
            request_id=request_id,
            exc_info=True
        )
        raise HTTPException(status_code=500, detail="Internal server error")


@app.get("/stats")
async def get_stats() -> Dict[str, Any]:
    """Get webhook processing statistics."""
    return await webhook_processor.get_stats()


if __name__ == "__main__":
    import uvicorn
    
    logger.info(
        "Starting webhook handler",
        host=settings.server.host,
        port=settings.server.port
    )
    
    uvicorn.run(
        "webhook_handler.main:app",
        host=settings.server.host,
        port=settings.server.port,
        reload=False,
        log_config=None  # We handle logging ourselves
    )