"""Logging configuration for the webhook handler."""

import logging
import logging.handlers
import structlog
from pathlib import Path
from typing import Any, Dict

from .config import LoggingConfig


def setup_logging(config: LoggingConfig) -> None:
    """Set up structured logging."""
    
    # Ensure log directory exists
    log_file = Path(config.file)
    log_file.parent.mkdir(parents=True, exist_ok=True)
    
    # Configure standard library logging
    logging.basicConfig(
        format="%(message)s",
        stream=None,  # We'll use handlers instead
        level=getattr(logging, config.level.upper()),
    )
    
    # Set up file handler with rotation
    file_handler = logging.handlers.RotatingFileHandler(
        filename=config.file,
        maxBytes=config.max_size_mb * 1024 * 1024,
        backupCount=config.backup_count,
        encoding="utf-8"
    )
    
    # Set up console handler
    console_handler = logging.StreamHandler()
    
    # Configure formatters based on format setting
    if config.format == "json":
        formatter = structlog.stdlib.ProcessorFormatter(
            processor=structlog.dev.ConsoleRenderer(colors=False),
        )
    else:
        formatter = logging.Formatter(
            "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
        )
    
    file_handler.setFormatter(formatter)
    console_handler.setFormatter(formatter)
    
    # Get root logger and configure
    root_logger = logging.getLogger()
    root_logger.handlers.clear()
    root_logger.addHandler(file_handler)
    root_logger.addHandler(console_handler)
    
    # Configure structlog
    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.stdlib.ProcessorFormatter.wrap_for_formatter,
        ],
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )


def get_logger(name: str) -> structlog.stdlib.BoundLogger:
    """Get a structured logger."""
    return structlog.get_logger(name)


class RequestIDProcessor:
    """Add request ID to log entries."""
    
    def __init__(self) -> None:
        self._request_id: str = ""
    
    def set_request_id(self, request_id: str) -> None:
        """Set the current request ID."""
        self._request_id = request_id
    
    def __call__(self, logger: Any, method_name: str, event_dict: Dict[str, Any]) -> Dict[str, Any]:
        """Add request ID to event dict."""
        if self._request_id:
            event_dict["request_id"] = self._request_id
        return event_dict


# Global request ID processor instance
request_id_processor = RequestIDProcessor()