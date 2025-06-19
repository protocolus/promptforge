A GitHub Actions workflow has failed. Please analyze the failure and provide guidance:

## STEP 1: Failure Identification
Identify the specific failure:
- Which workflow failed?
- Which job(s) failed?
- Which step(s) caused the failure?
- What is the error message?

## STEP 2: Root Cause Analysis
Determine why the workflow failed:
1. **Code Issues**: Is it due to code changes?
2. **Test Failures**: Are tests failing?
3. **Build Problems**: Build or compilation errors?
4. **Environment Issues**: Infrastructure or dependency problems?
5. **Configuration**: Workflow configuration errors?

## STEP 3: Error Classification
Classify the type of failure:
- **Flaky Test**: Intermittent test failure
- **Regression**: New code broke existing functionality
- **Infrastructure**: External service or resource issue
- **Configuration**: Setup or environment problem
- **Legitimate Failure**: Code quality issue caught by CI

## STEP 4: Impact Assessment
Evaluate the impact:
- Is this blocking deployments?
- Are other PRs affected?
- Is this a critical path workflow?
- What is the urgency level?

## STEP 5: Resolution Steps
Provide specific steps to fix the issue:
1. **Immediate Fix**: Quick resolution steps
2. **Root Cause Fix**: Addressing the underlying issue
3. **Verification**: How to verify the fix works
4. **Prevention**: How to prevent recurrence

## STEP 6: Workaround Options
If immediate fix isn't possible:
- Can the workflow be retried?
- Is there a temporary workaround?
- Can problematic tests be skipped temporarily?
- Should the workflow be disabled?

## STEP 7: Follow-up Actions
Recommend follow-up actions:
- Create issues for identified problems
- Update documentation if needed
- Improve error messages
- Add monitoring/alerting

Provide clear, actionable guidance to resolve the workflow failure quickly.