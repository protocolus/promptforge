"""Pytest configuration and fixtures."""

import pytest
import tempfile
import shutil
from pathlib import Path


@pytest.fixture(scope="session")
def temp_dir():
    """Create a temporary directory for tests."""
    temp_path = Path(tempfile.mkdtemp())
    yield temp_path
    shutil.rmtree(temp_path)


@pytest.fixture
def sample_prompts(temp_dir):
    """Create sample prompt files for testing."""
    prompts_dir = temp_dir / "prompts"
    
    # Create prompt directories
    (prompts_dir / "issues").mkdir(parents=True)
    (prompts_dir / "pull_requests").mkdir(parents=True)
    (prompts_dir / "reviews").mkdir(parents=True)
    
    # Create sample prompt files
    (prompts_dir / "issues" / "new_issue.md").write_text(
        "Analyze this issue: {{issue_title}}"
    )
    (prompts_dir / "pull_requests" / "new_pr.md").write_text(
        "Review this PR: {{pr_title}}"
    )
    (prompts_dir / "reviews" / "pr_review_requested.md").write_text(
        "Review requested for PR: {{pr_number}}"
    )
    
    return prompts_dir