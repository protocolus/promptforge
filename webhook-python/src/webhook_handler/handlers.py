"""Event-specific handlers for different GitHub webhook events."""

import re
from abc import ABC, abstractmethod
from typing import Dict, List, Optional, Any
from pathlib import Path

from .clients import ClaudeClient, GitHubClient
from .prompts import PromptLoader, create_prompt_context
from .config import Settings
from .logging_config import get_logger

logger = get_logger(__name__)


class BaseHandler(ABC):
    """Base class for webhook event handlers."""
    
    def __init__(self, settings: Settings, claude_client: ClaudeClient, github_client: GitHubClient, prompt_loader: PromptLoader):
        self.settings = settings
        self.claude_client = claude_client
        self.github_client = github_client
        self.prompt_loader = prompt_loader
        self.outputs_dir = Path(settings.outputs.base_dir)
        self.outputs_dir.mkdir(parents=True, exist_ok=True)
    
    @abstractmethod
    async def handle(self, payload: Dict[str, Any], action: str) -> Dict[str, Any]:
        """Handle the webhook event."""
        pass
    
    def extract_labels_from_analysis(self, analysis: str) -> List[str]:
        """Extract suggested labels from Claude's analysis."""
        labels = []
        
        # Define label patterns
        label_patterns = {
            r'\bbug\b': 'bug',
            r'\benhancement\b': 'enhancement',
            r'\bquestion\b': 'question',
            r'\bdocumentation\b': 'documentation',
            r'\bmaintenance\b': 'maintenance',
            r'\bhigh.priority\b|\bpriority.high\b': 'priority-high',
            r'\bmedium.priority\b|\bpriority.medium\b': 'priority-medium',
            r'\blow.priority\b|\bpriority.low\b': 'priority-low',
            r'\beasy\b|\bdifficulty.easy\b': 'difficulty-easy',
            r'\bmoderate\b|\bdifficulty.moderate\b': 'difficulty-moderate',
            r'\bcomplex\b|\bdifficulty.complex\b': 'difficulty-complex',
            r'\bfrontend\b|\bcomponent.frontend\b': 'component-frontend',
            r'\bbackend\b|\bcomponent.backend\b': 'component-backend',
            r'\bdatabase\b|\bcomponent.database\b': 'component-database'
        }
        
        analysis_lower = analysis.lower()
        for pattern, label in label_patterns.items():
            if re.search(pattern, analysis_lower):
                labels.append(label)
        
        return list(set(labels))  # Remove duplicates
    
    def should_close_issue(self, analysis: str) -> bool:
        """Check if Claude recommends closing the issue."""
        return "RECOMMENDATION: CLOSE ISSUE" in analysis


class IssueHandler(BaseHandler):
    """Handler for GitHub issue events."""
    
    async def handle(self, payload: Dict[str, Any], action: str) -> Dict[str, Any]:
        """Handle issue events."""
        
        if action != "opened":
            return {"status": "ignored", "reason": f"action '{action}' not handled"}
        
        issue = payload.get("issue", {})
        issue_number = issue.get("number")
        repository = payload.get("repository", {})
        repo_name = repository.get("full_name")
        
        logger.info("Processing issue", repo=repo_name, issue=issue_number, action=action)
        
        try:
            # Check if already analyzed
            labels = [label["name"] for label in issue.get("labels", [])]
            if "clide-analyzed" in labels:
                logger.info("Issue already analyzed", issue=issue_number)
                return {"status": "skipped", "reason": "already analyzed"}
            
            # Load and render prompt
            context = create_prompt_context("issues", payload)
            prompt = self.prompt_loader.render_prompt("issues", action, context)
            
            if not prompt:
                logger.error("No prompt found for issue", action=action)
                return {"status": "error", "reason": "no prompt template"}
            
            # Create context for Claude
            issue_context = f"""# GitHub Issue Analysis Request

## Issue Details
- **Repository**: {repo_name}
- **Issue Number**: #{issue_number}
- **Title**: {issue.get('title', '')}
- **URL**: {issue.get('html_url', '')}
- **Author**: {issue.get('user', {}).get('login', '')}

## Issue Description
{issue.get('body', '')}
"""
            
            # Analyze with Claude
            analysis = await self.claude_client.analyze(prompt, issue_context)
            
            # Save analysis
            output_dir = self.outputs_dir / self.settings.outputs.directories["issues"]
            output_dir.mkdir(parents=True, exist_ok=True)
            
            analysis_file = output_dir / f"issue_{issue_number}_analysis.md"
            with open(analysis_file, 'w', encoding='utf-8') as f:
                f.write(analysis)
            
            # Extract labels and post comment
            repo_config = self.settings.get_repository_config(repo_name)
            if repo_config and repo_config.settings.get("apply_labels", True):
                suggested_labels = self.extract_labels_from_analysis(analysis)
                if suggested_labels:
                    await self.github_client.add_issue_labels(repo_name, issue_number, suggested_labels)
            
            # Post analysis comment
            if repo_config and repo_config.settings.get("post_analysis_comments", True):
                comment = f"""## 🤖 Automated Issue Analysis

Hi! I've automatically analyzed this issue using Claude Code. Here's my assessment:

---

{analysis}

---

*This analysis was generated automatically by the PromptForge webhook system. The suggestions above are AI-generated and should be reviewed by a human maintainer.*

*Issue analyzed at: {context.get('timestamp', 'unknown')}*"""
                
                await self.github_client.post_issue_comment(repo_name, issue_number, comment)
            
            # Check if should close
            if (repo_config and 
                repo_config.settings.get("auto_close_invalid", False) and 
                self.should_close_issue(analysis)):
                
                close_comment = """## Issue Closed by Automated Analysis

This issue has been automatically closed based on the analysis above.

If you believe this was closed in error, please feel free to provide additional context and request that a maintainer review the decision.

Thank you for your interest in the project!"""
                
                await self.github_client.close_issue(repo_name, issue_number, close_comment)
            
            # Mark as analyzed
            await self.github_client.add_issue_labels(repo_name, issue_number, ["clide-analyzed"])
            
            logger.info("Issue analysis completed", issue=issue_number)
            
            return {
                "status": "success",
                "issue_number": issue_number,
                "analysis_file": str(analysis_file),
                "labels_applied": suggested_labels if repo_config and repo_config.settings.get("apply_labels") else []
            }
            
        except Exception as e:
            logger.error("Error processing issue", issue=issue_number, error=str(e), exc_info=True)
            return {"status": "error", "error": str(e)}


class PullRequestHandler(BaseHandler):
    """Handler for GitHub pull request events."""
    
    async def handle(self, payload: Dict[str, Any], action: str) -> Dict[str, Any]:
        """Handle pull request events."""
        
        if action not in ["opened", "synchronize"]:
            return {"status": "ignored", "reason": f"action '{action}' not handled"}
        
        pr = payload.get("pull_request", {})
        pr_number = pr.get("number")
        repository = payload.get("repository", {})
        repo_name = repository.get("full_name")
        
        logger.info("Processing PR", repo=repo_name, pr=pr_number, action=action)
        
        try:
            # Get full PR details including diff
            pr_details = await self.github_client.get_pull_request(repo_name, pr_number)
            
            # Load and render prompt
            context = create_prompt_context("pull_request", payload)
            context.update(pr_details)  # Add detailed PR info
            
            prompt_action = "new_pr" if action == "opened" else "pr_updated"
            prompt = self.prompt_loader.render_prompt("pull_request", prompt_action, context)
            
            if not prompt:
                logger.error("No prompt found for PR", action=action)
                return {"status": "error", "reason": "no prompt template"}
            
            # Create context for Claude
            pr_context = f"""# GitHub Pull Request Analysis Request

## PR Details
- **Repository**: {repo_name}
- **PR Number**: #{pr_number}
- **Title**: {pr.get('title', '')}
- **URL**: {pr.get('html_url', '')}
- **Author**: {pr.get('user', {}).get('login', '')}
- **State**: {pr.get('state', '')}
- **Draft**: {pr.get('draft', False)}

## PR Description
{pr.get('body', '')}

## Files Changed
{', '.join(pr_details.get('files', []))}

## Statistics
- **Additions**: {pr_details.get('additions', 0)}
- **Deletions**: {pr_details.get('deletions', 0)}
- **Changed Files**: {pr_details.get('changed_files', 0)}

## Code Diff (truncated)
```diff
{pr_details.get('diff', '')[:5000]}...
```
"""
            
            # Analyze with Claude
            analysis = await self.claude_client.analyze(prompt, pr_context)
            
            # Save analysis
            output_dir = self.outputs_dir / self.settings.outputs.directories["pull_requests"]
            output_dir.mkdir(parents=True, exist_ok=True)
            
            analysis_file = output_dir / f"pr_{pr_number}_analysis.md"
            with open(analysis_file, 'w', encoding='utf-8') as f:
                f.write(analysis)
            
            # Post analysis comment
            repo_config = self.settings.get_repository_config(repo_name)
            if repo_config and repo_config.settings.get("post_analysis_comments", True):
                comment = f"""## 🔍 Automated PR Review

Hi! I've automatically reviewed this pull request using Claude Code. Here's my assessment:

---

{analysis}

---

*This review was generated automatically by the PromptForge webhook system. The suggestions above are AI-generated and should be reviewed by a human maintainer.*

*PR analyzed at: {context.get('timestamp', 'unknown')}*"""
                
                await self.github_client.post_pr_comment(repo_name, pr_number, comment)
            
            # Apply PR labels if configured
            if repo_config and repo_config.settings.get("apply_labels", True):
                # Extract PR-specific labels (size, type, etc.)
                pr_labels = self._extract_pr_labels(analysis, pr_details)
                if pr_labels:
                    await self.github_client.add_pr_labels(repo_name, pr_number, pr_labels)
            
            logger.info("PR analysis completed", pr=pr_number)
            
            return {
                "status": "success",
                "pr_number": pr_number,
                "analysis_file": str(analysis_file),
                "action": action
            }
            
        except Exception as e:
            logger.error("Error processing PR", pr=pr_number, error=str(e), exc_info=True)
            return {"status": "error", "error": str(e)}
    
    def _extract_pr_labels(self, analysis: str, pr_details: Dict[str, Any]) -> List[str]:
        """Extract PR-specific labels."""
        labels = []
        
        # Size labels based on changes
        total_changes = pr_details.get('additions', 0) + pr_details.get('deletions', 0)
        if total_changes < 50:
            labels.append('size/small')
        elif total_changes < 200:
            labels.append('size/medium')
        else:
            labels.append('size/large')
        
        # Type labels from analysis
        analysis_lower = analysis.lower()
        if 'bug' in analysis_lower or 'fix' in analysis_lower:
            labels.append('type/bug-fix')
        elif 'feature' in analysis_lower or 'enhancement' in analysis_lower:
            labels.append('type/feature')
        elif 'refactor' in analysis_lower:
            labels.append('type/refactor')
        elif 'documentation' in analysis_lower or 'docs' in analysis_lower:
            labels.append('type/docs')
        
        return labels


class ReviewHandler(BaseHandler):
    """Handler for GitHub pull request review events."""
    
    async def handle(self, payload: Dict[str, Any], action: str) -> Dict[str, Any]:
        """Handle review request events."""
        
        pr = payload.get("pull_request", {})
        pr_number = pr.get("number")
        repository = payload.get("repository", {})
        repo_name = repository.get("full_name")
        
        # Handle review requests
        if "requested_reviewer" in payload:
            reviewer = payload.get("requested_reviewer", {}).get("login", "")
            requester = payload.get("sender", {}).get("login", "")
            
            logger.info("Processing review request", repo=repo_name, pr=pr_number, reviewer=reviewer)
            
            try:
                # Get full PR details
                pr_details = await self.github_client.get_pull_request(repo_name, pr_number)
                
                # Load and render prompt
                context = create_prompt_context("pull_request_review", payload)
                context.update(pr_details)
                context.update({
                    "reviewer": reviewer,
                    "requester": requester
                })
                
                prompt = self.prompt_loader.render_prompt("pull_request_review", "requested", context)
                
                if not prompt:
                    logger.error("No prompt found for review request")
                    return {"status": "error", "reason": "no prompt template"}
                
                # Create context for Claude
                review_context = f"""# GitHub Pull Request Review Request

## Review Request Details
- **Repository**: {repo_name}
- **PR Number**: #{pr_number}
- **PR Title**: {pr.get('title', '')}
- **PR Author**: {pr.get('user', {}).get('login', '')}
- **Reviewer Requested**: {reviewer}
- **Requested By**: {requester}

## PR Description
{pr.get('body', '')}

## Files to Review
{', '.join(pr_details.get('files', []))}

## Code Changes
```diff
{pr_details.get('diff', '')[:8000]}...
```
"""
                
                # Analyze with Claude
                analysis = await self.claude_client.analyze(prompt, review_context)
                
                # Save analysis
                output_dir = self.outputs_dir / self.settings.outputs.directories["reviews"]
                output_dir.mkdir(parents=True, exist_ok=True)
                
                import time
                timestamp = int(time.time())
                analysis_file = output_dir / f"pr_{pr_number}_review_{timestamp}.md"
                with open(analysis_file, 'w', encoding='utf-8') as f:
                    f.write(analysis)
                
                # Post review comment
                repo_config = self.settings.get_repository_config(repo_name)
                if repo_config and repo_config.settings.get("post_analysis_comments", True):
                    comment = f"""## 👁️ Automated Code Review

A review was requested from **{reviewer}**. Here's an automated analysis to help with the review:

---

{analysis}

---

*This review was generated automatically by the PromptForge webhook system. The suggestions above are AI-generated and should supplement, not replace, human code review.*

*Review analysis completed at: {context.get('timestamp', 'unknown')}*"""
                    
                    await self.github_client.post_pr_comment(repo_name, pr_number, comment)
                
                logger.info("Review analysis completed", pr=pr_number, reviewer=reviewer)
                
                return {
                    "status": "success",
                    "pr_number": pr_number,
                    "reviewer": reviewer,
                    "analysis_file": str(analysis_file)
                }
                
            except Exception as e:
                logger.error("Error processing review request", pr=pr_number, error=str(e), exc_info=True)
                return {"status": "error", "error": str(e)}
        
        return {"status": "ignored", "reason": "not a review request"}


class WorkflowHandler(BaseHandler):
    """Handler for GitHub workflow events."""
    
    async def handle(self, payload: Dict[str, Any], action: str) -> Dict[str, Any]:
        """Handle workflow events."""
        
        if action != "completed":
            return {"status": "ignored", "reason": f"action '{action}' not handled"}
        
        workflow_run = payload.get("workflow_run", {})
        conclusion = workflow_run.get("conclusion")
        
        if conclusion != "failure":
            return {"status": "ignored", "reason": f"conclusion '{conclusion}' not handled"}
        
        workflow_name = workflow_run.get("name", "")
        workflow_id = workflow_run.get("id")
        repository = payload.get("repository", {})
        repo_name = repository.get("full_name")
        
        logger.info("Processing failed workflow", repo=repo_name, workflow=workflow_name, run_id=workflow_id)
        
        try:
            # Load and render prompt
            context = create_prompt_context("workflow_run", payload)
            prompt = self.prompt_loader.render_prompt("workflow_run", "completed", context)
            
            if not prompt:
                logger.error("No prompt found for workflow failure")
                return {"status": "error", "reason": "no prompt template"}
            
            # Create context for Claude
            workflow_context = f"""# GitHub Workflow Failure Analysis

## Workflow Details
- **Repository**: {repo_name}
- **Workflow**: {workflow_name}
- **Run ID**: {workflow_id}
- **Conclusion**: {conclusion}
- **Commit**: {workflow_run.get('head_sha', '')}
- **Branch**: {workflow_run.get('head_branch', '')}

## Workflow URL
{workflow_run.get('html_url', '')}

## Commit Message
{workflow_run.get('head_commit', {}).get('message', '')}
"""
            
            # Analyze with Claude
            analysis = await self.claude_client.analyze(prompt, workflow_context)
            
            # Save analysis
            output_dir = self.outputs_dir / self.settings.outputs.directories["workflows"]
            output_dir.mkdir(parents=True, exist_ok=True)
            
            analysis_file = output_dir / f"workflow_{workflow_id}_analysis.md"
            with open(analysis_file, 'w', encoding='utf-8') as f:
                f.write(analysis)
            
            logger.info("Workflow failure analysis completed", workflow=workflow_name, run_id=workflow_id)
            
            return {
                "status": "success",
                "workflow_name": workflow_name,
                "run_id": workflow_id,
                "analysis_file": str(analysis_file)
            }
            
        except Exception as e:
            logger.error("Error processing workflow failure", workflow=workflow_name, error=str(e), exc_info=True)
            return {"status": "error", "error": str(e)}


# Handler registry
HANDLERS = {
    "issues": IssueHandler,
    "pull_request": PullRequestHandler,
    "pull_request_review": ReviewHandler,
    "workflow_run": WorkflowHandler,
}