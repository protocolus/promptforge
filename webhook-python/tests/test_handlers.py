"""Tests for webhook event handlers."""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from webhook_handler.handlers import IssueHandler, PullRequestHandler
from webhook_handler.config import Settings


@pytest.fixture
def mock_settings():
    """Mock settings for testing."""
    settings = MagicMock(spec=Settings)
    settings.outputs.base_dir = "/tmp/test_outputs"
    settings.outputs.directories = {
        "issues": "issues",
        "pull_requests": "pull_requests",
        "reviews": "reviews",
        "workflows": "workflows"
    }
    
    # Mock repository config
    repo_config = MagicMock()
    repo_config.settings = {
        "post_analysis_comments": True,
        "apply_labels": True,
        "auto_close_invalid": False
    }
    settings.get_repository_config.return_value = repo_config
    
    return settings


@pytest.fixture
def mock_clients():
    """Mock Claude and GitHub clients."""
    claude_client = AsyncMock()
    claude_client.analyze.return_value = "Mock analysis result"
    
    github_client = AsyncMock()
    github_client.post_issue_comment.return_value = True
    github_client.add_issue_labels.return_value = True
    
    return claude_client, github_client


@pytest.fixture
def mock_prompt_loader():
    """Mock prompt loader."""
    prompt_loader = MagicMock()
    prompt_loader.render_prompt.return_value = "Mock prompt template"
    return prompt_loader


@pytest.fixture
def issue_payload():
    """Sample issue payload."""
    return {
        "action": "opened",
        "issue": {
            "number": 123,
            "title": "Test issue",
            "body": "This is a test issue",
            "html_url": "https://github.com/test/repo/issues/123",
            "user": {"login": "testuser"},
            "labels": []
        },
        "repository": {
            "full_name": "test/repo",
            "html_url": "https://github.com/test/repo"
        },
        "sender": {"login": "testuser"}
    }


@pytest.fixture
def pr_payload():
    """Sample PR payload."""
    return {
        "action": "opened",
        "pull_request": {
            "number": 456,
            "title": "Test PR",
            "body": "This is a test PR",
            "html_url": "https://github.com/test/repo/pull/456",
            "user": {"login": "testuser"},
            "labels": [],
            "state": "open",
            "draft": False
        },
        "repository": {
            "full_name": "test/repo",
            "html_url": "https://github.com/test/repo"
        },
        "sender": {"login": "testuser"}
    }


class TestIssueHandler:
    """Tests for IssueHandler."""
    
    @pytest.mark.asyncio
    async def test_handle_new_issue(
        self, mock_settings, mock_clients, mock_prompt_loader, issue_payload
    ):
        """Test handling a new issue."""
        claude_client, github_client = mock_clients
        
        handler = IssueHandler(
            mock_settings, claude_client, github_client, mock_prompt_loader
        )
        
        with patch("pathlib.Path.mkdir"), \
             patch("builtins.open", MagicMock()):
            
            result = await handler.handle(issue_payload, "opened")
        
        # Verify the result
        assert result["status"] == "success"
        assert result["issue_number"] == 123
        
        # Verify Claude was called
        claude_client.analyze.assert_called_once()
        
        # Verify GitHub interactions
        github_client.post_issue_comment.assert_called_once()
        github_client.add_issue_labels.assert_called()
    
    @pytest.mark.asyncio
    async def test_handle_already_analyzed_issue(
        self, mock_settings, mock_clients, mock_prompt_loader, issue_payload
    ):
        """Test handling an issue that's already analyzed."""
        claude_client, github_client = mock_clients
        
        # Mark issue as already analyzed
        issue_payload["issue"]["labels"] = [{"name": "clide-analyzed"}]
        
        handler = IssueHandler(
            mock_settings, claude_client, github_client, mock_prompt_loader
        )
        
        result = await handler.handle(issue_payload, "opened")
        
        # Should skip processing
        assert result["status"] == "skipped"
        assert result["reason"] == "already analyzed"
        
        # Should not call Claude or GitHub
        claude_client.analyze.assert_not_called()
        github_client.post_issue_comment.assert_not_called()
    
    @pytest.mark.asyncio
    async def test_handle_unsupported_action(
        self, mock_settings, mock_clients, mock_prompt_loader, issue_payload
    ):
        """Test handling an unsupported action."""
        claude_client, github_client = mock_clients
        
        handler = IssueHandler(
            mock_settings, claude_client, github_client, mock_prompt_loader
        )
        
        result = await handler.handle(issue_payload, "closed")
        
        # Should ignore unsupported actions
        assert result["status"] == "ignored"
        assert "not handled" in result["reason"]
    
    def test_extract_labels_from_analysis(
        self, mock_settings, mock_clients, mock_prompt_loader
    ):
        """Test label extraction from analysis."""
        claude_client, github_client = mock_clients
        
        handler = IssueHandler(
            mock_settings, claude_client, github_client, mock_prompt_loader
        )
        
        analysis = """
        This is a bug report with high priority.
        The issue is complex and affects the frontend component.
        Classification: enhancement
        Priority: high
        Difficulty: complex
        Component: frontend
        """
        
        labels = handler.extract_labels_from_analysis(analysis)
        
        expected_labels = {
            "bug", "enhancement", "priority-high", 
            "difficulty-complex", "component-frontend"
        }
        
        assert set(labels) == expected_labels
    
    def test_should_close_issue(
        self, mock_settings, mock_clients, mock_prompt_loader
    ):
        """Test issue closure detection."""
        claude_client, github_client = mock_clients
        
        handler = IssueHandler(
            mock_settings, claude_client, github_client, mock_prompt_loader
        )
        
        # Analysis recommending closure
        close_analysis = "RECOMMENDATION: CLOSE ISSUE - This is spam"
        assert handler.should_close_issue(close_analysis) is True
        
        # Analysis not recommending closure
        keep_analysis = "This is a valid enhancement request"
        assert handler.should_close_issue(keep_analysis) is False


class TestPullRequestHandler:
    """Tests for PullRequestHandler."""
    
    @pytest.mark.asyncio
    async def test_handle_new_pr(
        self, mock_settings, mock_clients, mock_prompt_loader, pr_payload
    ):
        """Test handling a new pull request."""
        claude_client, github_client = mock_clients
        
        # Mock PR details
        pr_details = {
            "files": ["file1.py", "file2.py"],
            "diff": "mock diff content",
            "additions": 50,
            "deletions": 10,
            "changed_files": 2
        }
        github_client.get_pull_request.return_value = pr_details
        
        handler = PullRequestHandler(
            mock_settings, claude_client, github_client, mock_prompt_loader
        )
        
        with patch("pathlib.Path.mkdir"), \
             patch("builtins.open", MagicMock()):
            
            result = await handler.handle(pr_payload, "opened")
        
        # Verify the result
        assert result["status"] == "success"
        assert result["pr_number"] == 456
        assert result["action"] == "opened"
        
        # Verify GitHub client calls
        github_client.get_pull_request.assert_called_once_with("test/repo", 456)
        github_client.post_pr_comment.assert_called_once()
    
    def test_extract_pr_labels(
        self, mock_settings, mock_clients, mock_prompt_loader
    ):
        """Test PR label extraction."""
        claude_client, github_client = mock_clients
        
        handler = PullRequestHandler(
            mock_settings, claude_client, github_client, mock_prompt_loader
        )
        
        # Small PR
        pr_details = {"additions": 20, "deletions": 5}
        analysis = "This is a bug fix"
        
        labels = handler._extract_pr_labels(analysis, pr_details)
        
        assert "size/small" in labels
        assert "type/bug-fix" in labels
        
        # Large feature PR
        pr_details = {"additions": 500, "deletions": 100}
        analysis = "This adds a new feature with documentation"
        
        labels = handler._extract_pr_labels(analysis, pr_details)
        
        assert "size/large" in labels
        assert "type/feature" in labels


@pytest.mark.asyncio
async def test_handler_error_handling(
    mock_settings, mock_clients, mock_prompt_loader, issue_payload
):
    """Test error handling in handlers."""
    claude_client, github_client = mock_clients
    
    # Make Claude client raise an exception
    claude_client.analyze.side_effect = Exception("Claude API error")
    
    handler = IssueHandler(
        mock_settings, claude_client, github_client, mock_prompt_loader
    )
    
    result = await handler.handle(issue_payload, "opened")
    
    # Should return error status
    assert result["status"] == "error"
    assert "Claude API error" in result["error"]