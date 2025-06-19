"""Configuration management for the webhook handler."""

import os
import yaml
from typing import Dict, List, Optional, Any
from pydantic import BaseSettings, Field
from pydantic_settings import SettingsConfigDict


class ServerConfig(BaseSettings):
    """Server configuration."""
    host: str = "0.0.0.0"
    port: int = 9000
    webhook_path: str = "/github-webhook"


class GitHubConfig(BaseSettings):
    """GitHub API configuration."""
    token: str = Field(..., env="GITHUB_TOKEN")
    webhook_secret: str = Field(..., env="GITHUB_WEBHOOK_SECRET")


class ClaudeConfig(BaseSettings):
    """Claude API configuration."""
    api_key: str = Field(..., env="ANTHROPIC_API_KEY")
    model: str = "claude-3-sonnet-20240229"
    max_tokens: int = 4000


class RepositoryConfig(BaseSettings):
    """Repository-specific configuration."""
    name: str
    events: List[str]
    settings: Dict[str, Any] = {}


class PromptsConfig(BaseSettings):
    """Prompts configuration."""
    base_dir: str = "./prompts"
    templates: Dict[str, Dict[str, str]] = {}


class OutputsConfig(BaseSettings):
    """Output directories configuration."""
    base_dir: str = "./outputs"
    directories: Dict[str, str] = {}


class LoggingConfig(BaseSettings):
    """Logging configuration."""
    level: str = "INFO"
    format: str = "json"
    file: str = "./logs/webhook.log"
    max_size_mb: int = 10
    backup_count: int = 5


class FeaturesConfig(BaseSettings):
    """Feature flags configuration."""
    async_processing: bool = True
    rate_limiting: bool = True
    signature_validation: bool = True
    payload_logging: bool = False


class Settings(BaseSettings):
    """Main settings class."""
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore"
    )
    
    server: ServerConfig = ServerConfig()
    github: GitHubConfig = GitHubConfig()
    claude: ClaudeConfig = ClaudeConfig()
    repositories: List[RepositoryConfig] = []
    prompts: PromptsConfig = PromptsConfig()
    outputs: OutputsConfig = OutputsConfig()
    logging: LoggingConfig = LoggingConfig()
    features: FeaturesConfig = FeaturesConfig()

    @classmethod
    def from_yaml(cls, config_path: str) -> "Settings":
        """Load settings from YAML file with environment variable substitution."""
        with open(config_path, 'r') as f:
            config_data = yaml.safe_load(f)
        
        # Substitute environment variables
        config_data = cls._substitute_env_vars(config_data)
        
        return cls(**config_data)
    
    @staticmethod
    def _substitute_env_vars(obj: Any) -> Any:
        """Recursively substitute environment variables in config."""
        if isinstance(obj, dict):
            return {k: Settings._substitute_env_vars(v) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [Settings._substitute_env_vars(item) for item in obj]
        elif isinstance(obj, str) and obj.startswith("${") and obj.endswith("}"):
            env_var = obj[2:-1]
            return os.getenv(env_var, obj)
        else:
            return obj

    def get_repository_config(self, repo_name: str) -> Optional[RepositoryConfig]:
        """Get configuration for a specific repository."""
        for repo in self.repositories:
            if repo.name == repo_name:
                return repo
        return None

    def is_event_enabled(self, repo_name: str, event_type: str) -> bool:
        """Check if an event type is enabled for a repository."""
        repo_config = self.get_repository_config(repo_name)
        if not repo_config:
            return False
        return event_type in repo_config.events