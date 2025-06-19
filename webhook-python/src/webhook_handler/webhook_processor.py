"""Main webhook processor that coordinates all components."""

import time
from typing import Dict, Any, Optional
from collections import defaultdict, deque

from .config import Settings
from .clients import ClaudeClient, GitHubClient
from .prompts import PromptLoader
from .handlers import HANDLERS
from .logging_config import get_logger, request_id_processor

logger = get_logger(__name__)


class WebhookProcessor:
    """Main processor for GitHub webhooks."""
    
    def __init__(self, settings: Settings):
        self.settings = settings
        
        # Initialize clients
        self.claude_client = ClaudeClient(settings.claude)
        self.github_client = GitHubClient(settings.github)
        self.prompt_loader = PromptLoader(settings.prompts)
        
        # Initialize handlers
        self.handlers = {}
        for event_type, handler_class in HANDLERS.items():
            self.handlers[event_type] = handler_class(
                settings, self.claude_client, self.github_client, self.prompt_loader
            )
        
        # Statistics tracking
        self.stats = {
            "total_webhooks": 0,
            "successful_processing": 0,
            "failed_processing": 0,
            "events_by_type": defaultdict(int),
            "events_by_repo": defaultdict(int),
            "processing_times": deque(maxlen=100),  # Keep last 100 processing times
            "start_time": time.time()
        }
        
        logger.info(
            "WebhookProcessor initialized",
            handlers=list(self.handlers.keys()),
            repositories=[repo.name for repo in settings.repositories]
        )
    
    async def process_webhook(
        self, 
        event_type: str, 
        payload: Dict[str, Any], 
        delivery_id: Optional[str] = None,
        request_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """Process a webhook event."""
        
        start_time = time.time()
        
        # Set request ID for logging context
        if request_id:
            request_id_processor.set_request_id(request_id)
        
        # Update statistics
        self.stats["total_webhooks"] += 1
        self.stats["events_by_type"][event_type] += 1
        
        # Extract repository name
        repository = payload.get("repository", {})
        repo_name = repository.get("full_name", "unknown")
        self.stats["events_by_repo"][repo_name] += 1
        
        # Extract action
        action = payload.get("action", "")
        
        logger.info(
            "Processing webhook",
            event_type=event_type,
            action=action,
            repository=repo_name,
            delivery_id=delivery_id
        )
        
        try:
            # Check if we have a handler for this event type
            if event_type not in self.handlers:
                logger.warning("No handler for event type", event_type=event_type)
                return {
                    "status": "ignored",
                    "reason": f"no handler for event type '{event_type}'"
                }
            
            # Get repository configuration
            repo_config = self.settings.get_repository_config(repo_name)
            if not repo_config:
                logger.info("Repository not configured", repository=repo_name)
                return {
                    "status": "ignored",
                    "reason": "repository not configured"
                }
            
            # Check if event is enabled for this repository
            if not self.settings.is_event_enabled(repo_name, event_type):
                logger.info(
                    "Event type not enabled for repository",
                    event_type=event_type,
                    repository=repo_name
                )
                return {
                    "status": "ignored",
                    "reason": "event type not enabled"
                }
            
            # Process with appropriate handler
            handler = self.handlers[event_type]
            result = await handler.handle(payload, action)
            
            # Update success statistics
            if result.get("status") == "success":
                self.stats["successful_processing"] += 1
            elif result.get("status") == "error":
                self.stats["failed_processing"] += 1
            
            # Record processing time
            processing_time = time.time() - start_time
            self.stats["processing_times"].append(processing_time)
            
            logger.info(
                "Webhook processing completed",
                event_type=event_type,
                repository=repo_name,
                result_status=result.get("status"),
                processing_time=f"{processing_time:.2f}s"
            )
            
            return result
            
        except Exception as e:
            self.stats["failed_processing"] += 1
            processing_time = time.time() - start_time
            self.stats["processing_times"].append(processing_time)
            
            logger.error(
                "Error processing webhook",
                event_type=event_type,
                repository=repo_name,
                error=str(e),
                processing_time=f"{processing_time:.2f}s",
                exc_info=True
            )
            
            return {
                "status": "error",
                "error": str(e),
                "event_type": event_type,
                "repository": repo_name
            }
    
    async def get_stats(self) -> Dict[str, Any]:
        """Get processing statistics."""
        
        # Calculate average processing time
        processing_times = list(self.stats["processing_times"])
        avg_processing_time = sum(processing_times) / len(processing_times) if processing_times else 0
        
        # Calculate uptime
        uptime = time.time() - self.stats["start_time"]
        
        # Get client stats
        github_stats = self.github_client.get_stats()
        
        stats = {
            "uptime_seconds": uptime,
            "total_webhooks": self.stats["total_webhooks"],
            "successful_processing": self.stats["successful_processing"],
            "failed_processing": self.stats["failed_processing"],
            "success_rate": (
                self.stats["successful_processing"] / self.stats["total_webhooks"] 
                if self.stats["total_webhooks"] > 0 else 0
            ),
            "average_processing_time": avg_processing_time,
            "events_by_type": dict(self.stats["events_by_type"]),
            "events_by_repo": dict(self.stats["events_by_repo"]),
            "github_api": github_stats,
            "handlers": list(self.handlers.keys()),
            "repositories": [repo.name for repo in self.settings.repositories]
        }
        
        return stats
    
    async def setup_repository_labels(self, repo_name: str) -> bool:
        """Set up required labels for a repository."""
        
        logger.info("Setting up repository labels", repository=repo_name)
        
        # Standard labels for issue and PR management
        labels = [
            {"name": "bug", "color": "d73a4a", "description": "Something isn't working"},
            {"name": "enhancement", "color": "a2eeef", "description": "New feature or request"},
            {"name": "question", "color": "d876e3", "description": "Further information is requested"},
            {"name": "documentation", "color": "0075ca", "description": "Improvements or additions to documentation"},
            {"name": "maintenance", "color": "fbca04", "description": "Code cleanup, refactoring, or maintenance"},
            
            # Priority labels
            {"name": "priority-high", "color": "d73a4a", "description": "High priority"},
            {"name": "priority-medium", "color": "fbca04", "description": "Medium priority"},
            {"name": "priority-low", "color": "0e8a16", "description": "Low priority"},
            
            # Difficulty labels
            {"name": "difficulty-easy", "color": "0e8a16", "description": "Easy to implement"},
            {"name": "difficulty-moderate", "color": "fbca04", "description": "Moderate difficulty"},
            {"name": "difficulty-complex", "color": "d73a4a", "description": "Complex implementation"},
            
            # Component labels
            {"name": "component-frontend", "color": "1d76db", "description": "Frontend/UI related"},
            {"name": "component-backend", "color": "0e8a16", "description": "Backend/API related"},
            {"name": "component-database", "color": "5319e7", "description": "Database related"},
            
            # Special labels
            {"name": "clide-analyzed", "color": "c5def5", "description": "Analyzed by Claude Code"},
            {"name": "wontfix", "color": "ffffff", "description": "This will not be worked on"},
            {"name": "invalid", "color": "e4e669", "description": "This doesn't seem right"},
            
            # PR labels
            {"name": "size/small", "color": "00ff00", "description": "Small PR"},
            {"name": "size/medium", "color": "ffff00", "description": "Medium PR"},
            {"name": "size/large", "color": "ff0000", "description": "Large PR"},
            {"name": "type/bug-fix", "color": "d73a4a", "description": "Bug fix"},
            {"name": "type/feature", "color": "a2eeef", "description": "New feature"},
            {"name": "type/refactor", "color": "fbca04", "description": "Code refactoring"},
            {"name": "type/docs", "color": "0075ca", "description": "Documentation changes"},
            {"name": "status/needs-review", "color": "fbca04", "description": "Needs review"},
            {"name": "status/needs-changes", "color": "d73a4a", "description": "Needs changes"},
            {"name": "status/approved", "color": "0e8a16", "description": "Approved for merge"},
        ]
        
        try:
            await self.github_client.create_repository_labels(repo_name, labels)
            logger.info("Repository labels setup completed", repository=repo_name)
            return True
        except Exception as e:
            logger.error("Failed to setup repository labels", repository=repo_name, error=str(e))
            return False
    
    async def health_check(self) -> Dict[str, Any]:
        """Perform a health check on all components."""
        
        health = {
            "status": "healthy",
            "timestamp": time.time(),
            "components": {}
        }
        
        try:
            # Check if we can load prompts
            available_prompts = self.prompt_loader.list_available_prompts()
            health["components"]["prompt_loader"] = {
                "status": "healthy",
                "available_prompts": len(available_prompts)
            }
        except Exception as e:
            health["components"]["prompt_loader"] = {
                "status": "unhealthy",
                "error": str(e)
            }
            health["status"] = "degraded"
        
        try:
            # Check GitHub API (get rate limit)
            github_stats = self.github_client.get_stats()
            health["components"]["github_client"] = {
                "status": "healthy",
                "rate_limit": github_stats["rate_limit"]
            }
        except Exception as e:
            health["components"]["github_client"] = {
                "status": "unhealthy",
                "error": str(e)
            }
            health["status"] = "degraded"
        
        # Claude client health (we can't easily test without making a request)
        health["components"]["claude_client"] = {
            "status": "assumed_healthy",
            "note": "Cannot test without making API request"
        }
        
        return health