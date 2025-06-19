"""API clients for Claude and GitHub."""

import asyncio
import time
from typing import Dict, List, Optional, Any
from pathlib import Path

import requests
from anthropic import Anthropic
from github import Github, GithubException

from .config import ClaudeConfig, GitHubConfig
from .logging_config import get_logger

logger = get_logger(__name__)


class ClaudeClient:
    """Client for interacting with Claude API."""
    
    def __init__(self, config: ClaudeConfig):
        self.config = config
        self.client = Anthropic(api_key=config.api_key)
        self._request_count = 0
        self._last_request_time = 0.0
    
    async def analyze(self, prompt: str, context: str) -> str:
        """Analyze content using Claude."""
        
        # Simple rate limiting
        current_time = time.time()
        if current_time - self._last_request_time < 1.0:  # 1 second between requests
            await asyncio.sleep(1.0 - (current_time - self._last_request_time))
        
        self._last_request_time = time.time()
        self._request_count += 1
        
        try:
            # Combine prompt and context
            full_prompt = f"{context}\n\n{prompt}"
            
            logger.info("Sending request to Claude", request_count=self._request_count)
            
            # Make synchronous call in thread pool to avoid blocking
            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                None,
                self._make_claude_request,
                full_prompt
            )
            
            logger.info("Received response from Claude", response_length=len(response))
            return response
            
        except Exception as e:
            logger.error("Claude API error", error=str(e), exc_info=True)
            raise
    
    def _make_claude_request(self, prompt: str) -> str:
        """Make the actual Claude API request."""
        response = self.client.messages.create(
            model=self.config.model,
            max_tokens=self.config.max_tokens,
            messages=[{
                "role": "user",
                "content": prompt
            }]
        )
        
        return response.content[0].text if response.content else ""


class GitHubClient:
    """Client for interacting with GitHub API."""
    
    def __init__(self, config: GitHubConfig):
        self.config = config
        self.client = Github(config.token)
        self._request_count = 0
    
    async def get_issue(self, repo_name: str, issue_number: int) -> Dict[str, Any]:
        """Get issue details."""
        try:
            repo = self.client.get_repo(repo_name)
            issue = repo.get_issue(issue_number)
            
            return {
                "number": issue.number,
                "title": issue.title,
                "body": issue.body or "",
                "user": issue.user.login,
                "state": issue.state,
                "labels": [label.name for label in issue.labels],
                "url": issue.html_url
            }
        except GithubException as e:
            logger.error("GitHub API error getting issue", error=str(e))
            raise
    
    async def get_pull_request(self, repo_name: str, pr_number: int) -> Dict[str, Any]:
        """Get pull request details."""
        try:
            repo = self.client.get_repo(repo_name)
            pr = repo.get_pull(pr_number)
            
            # Get diff (limited size)
            diff_content = ""
            try:
                diff_response = requests.get(
                    pr.diff_url,
                    headers={"Authorization": f"token {self.config.token}"}
                )
                if diff_response.status_code == 200:
                    diff_content = diff_response.text[:10000]  # Limit diff size
            except Exception as e:
                logger.warning("Could not fetch PR diff", error=str(e))
            
            return {
                "number": pr.number,
                "title": pr.title,
                "body": pr.body or "",
                "user": pr.user.login,
                "state": pr.state,
                "labels": [label.name for label in pr.labels],
                "url": pr.html_url,
                "diff": diff_content,
                "files": [f.filename for f in pr.get_files()],
                "additions": pr.additions,
                "deletions": pr.deletions,
                "changed_files": pr.changed_files
            }
        except GithubException as e:
            logger.error("GitHub API error getting PR", error=str(e))
            raise
    
    async def post_issue_comment(self, repo_name: str, issue_number: int, comment: str) -> bool:
        """Post a comment on an issue."""
        try:
            repo = self.client.get_repo(repo_name)
            issue = repo.get_issue(issue_number)
            issue.create_comment(comment)
            
            logger.info("Posted comment on issue", repo=repo_name, issue=issue_number)
            return True
        except GithubException as e:
            logger.error("Failed to post issue comment", error=str(e))
            return False
    
    async def post_pr_comment(self, repo_name: str, pr_number: int, comment: str) -> bool:
        """Post a comment on a pull request."""
        try:
            repo = self.client.get_repo(repo_name)
            pr = repo.get_pull(pr_number)
            pr.create_issue_comment(comment)
            
            logger.info("Posted comment on PR", repo=repo_name, pr=pr_number)
            return True
        except GithubException as e:
            logger.error("Failed to post PR comment", error=str(e))
            return False
    
    async def add_issue_labels(self, repo_name: str, issue_number: int, labels: List[str]) -> bool:
        """Add labels to an issue."""
        try:
            repo = self.client.get_repo(repo_name)
            issue = repo.get_issue(issue_number)
            
            # Get existing labels to avoid duplicates
            existing_labels = {label.name for label in issue.labels}
            new_labels = [label for label in labels if label not in existing_labels]
            
            if new_labels:
                issue.add_to_labels(*new_labels)
                logger.info("Added labels to issue", repo=repo_name, issue=issue_number, labels=new_labels)
            
            return True
        except GithubException as e:
            logger.error("Failed to add issue labels", error=str(e))
            return False
    
    async def add_pr_labels(self, repo_name: str, pr_number: int, labels: List[str]) -> bool:
        """Add labels to a pull request."""
        try:
            repo = self.client.get_repo(repo_name)
            pr = repo.get_pull(pr_number)
            
            # Get existing labels to avoid duplicates
            existing_labels = {label.name for label in pr.labels}
            new_labels = [label for label in labels if label not in existing_labels]
            
            if new_labels:
                pr.add_to_labels(*new_labels)
                logger.info("Added labels to PR", repo=repo_name, pr=pr_number, labels=new_labels)
            
            return True
        except GithubException as e:
            logger.error("Failed to add PR labels", error=str(e))
            return False
    
    async def close_issue(self, repo_name: str, issue_number: int, comment: Optional[str] = None) -> bool:
        """Close an issue."""
        try:
            repo = self.client.get_repo(repo_name)
            issue = repo.get_issue(issue_number)
            
            if comment:
                issue.create_comment(comment)
            
            issue.edit(state="closed")
            logger.info("Closed issue", repo=repo_name, issue=issue_number)
            return True
        except GithubException as e:
            logger.error("Failed to close issue", error=str(e))
            return False
    
    async def create_repository_labels(self, repo_name: str, labels: List[Dict[str, str]]) -> None:
        """Create repository labels if they don't exist."""
        try:
            repo = self.client.get_repo(repo_name)
            existing_labels = {label.name for label in repo.get_labels()}
            
            for label_info in labels:
                if label_info["name"] not in existing_labels:
                    try:
                        repo.create_label(
                            name=label_info["name"],
                            color=label_info.get("color", "ffffff"),
                            description=label_info.get("description", "")
                        )
                        logger.info("Created label", repo=repo_name, label=label_info["name"])
                    except GithubException as e:
                        logger.warning("Failed to create label", label=label_info["name"], error=str(e))
        except GithubException as e:
            logger.error("Failed to setup repository labels", error=str(e))
    
    def get_stats(self) -> Dict[str, Any]:
        """Get client statistics."""
        rate_limit = self.client.get_rate_limit()
        
        return {
            "requests_made": self._request_count,
            "rate_limit": {
                "core": {
                    "limit": rate_limit.core.limit,
                    "remaining": rate_limit.core.remaining,
                    "reset": rate_limit.core.reset.isoformat()
                }
            }
        }