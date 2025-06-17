# Husky and ESLint Pre-commit Setup

This document explains how to install and configure Husky with ESLint for automated code quality checks before commits.

## Overview

Husky is a tool that allows you to run scripts at various Git hooks. We've configured it to run ESLint on staged files before commits to ensure code quality.

## Installation

### 1. Install Dependencies

```bash
# Install Husky and lint-staged as dev dependencies
npm install --save-dev husky lint-staged

# Install ESLint and React plugins
npm install --save-dev eslint @eslint/js eslint-plugin-react eslint-plugin-react-hooks
```

### 2. Initialize Husky

```bash
# Initialize Husky (adds prepare script to package.json)
npx husky init
```

## Configuration Files

### ESLint Configuration (`eslint.config.js`)

```javascript
import js from '@eslint/js';
import reactPlugin from 'eslint-plugin-react';
import reactHooksPlugin from 'eslint-plugin-react-hooks';

export default [
  js.configs.recommended,
  {
    files: ['**/*.js', '**/*.jsx'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      parserOptions: {
        ecmaFeatures: {
          jsx: true
        }
      },
      globals: {
        console: 'readonly',
        process: 'readonly',
        Buffer: 'readonly',
        __dirname: 'readonly',
        __filename: 'readonly',
        exports: 'writable',
        module: 'writable',
        require: 'readonly',
        global: 'readonly',
        URL: 'readonly',
        setTimeout: 'readonly',
        setInterval: 'readonly',
        clearTimeout: 'readonly',
        clearInterval: 'readonly',
        setImmediate: 'readonly',
        clearImmediate: 'readonly',
        // Browser globals
        window: 'readonly',
        document: 'readonly',
        navigator: 'readonly',
        fetch: 'readonly',
        alert: 'readonly',
        localStorage: 'readonly',
        sessionStorage: 'readonly'
      }
    },
    plugins: {
      react: reactPlugin,
      'react-hooks': reactHooksPlugin
    },
    rules: {
      ...reactPlugin.configs.recommended.rules,
      ...reactHooksPlugin.configs.recommended.rules,
      'no-unused-vars': 'error',
      'no-console': 'off',
      'react/prop-types': 'off',
      'react/react-in-jsx-scope': 'off'
    },
    settings: {
      react: {
        version: 'detect'
      }
    }
  },
  {
    ignores: [
      '**/node_modules/**',
      '**/build/**',
      '**/dist/**',
      '**/.git/**',
      '**/coverage/**',
      'promptforge.db',
      'logs/**'
    ]
  }
];
```

### Pre-commit Hook (`.husky/pre-commit`)

```bash
npx lint-staged
```

### Lint-staged Configuration (`package.json`)

```json
{
  "lint-staged": {
    "server/**/*.js": "eslint --config eslint.config.js --fix",
    "client/**/*.{js,jsx}": "eslint --config eslint.config.js --fix"
  }
}
```

### Package.json Scripts

Add these scripts to your package.json files:

**Root package.json:**
```json
{
  "scripts": {
    "lint": "cd server && npm run lint && cd ../client && npm run lint",
    "prepare": "husky"
  },
  "devDependencies": {
    "@eslint/js": "^9.29.0",
    "eslint": "^9.29.0",
    "eslint-plugin-react": "^7.37.5",
    "eslint-plugin-react-hooks": "^5.2.0",
    "husky": "^9.1.7",
    "lint-staged": "^16.1.2"
  }
}
```

**Server package.json:**
```json
{
  "scripts": {
    "lint": "eslint . --config ../eslint.config.js"
  }
}
```

**Client package.json:**
```json
{
  "scripts": {
    "lint": "eslint . --config ../eslint.config.js"
  }
}
```

## How It Works

1. **Pre-commit Hook**: When you run `git commit`, Husky triggers the pre-commit hook
2. **Lint-staged**: The hook runs `npx lint-staged` which processes only staged files
3. **ESLint**: For each staged JS/JSX file, ESLint runs with the `--fix` flag to automatically fix issues
4. **Commit Success/Failure**: 
   - If linting passes, the commit proceeds
   - If linting fails, the commit is blocked and you must fix the issues

## File Structure

```
promptforge/
├── .husky/
│   └── pre-commit           # Pre-commit hook script
├── eslint.config.js         # ESLint configuration
├── package.json             # Root dependencies and lint-staged config
├── server/
│   └── package.json         # Server lint script
└── client/
    └── package.json         # Client lint script
```

## Testing the Setup

1. **Make a change** to a JavaScript file
2. **Stage the file**: `git add filename.js`
3. **Attempt to commit**: `git commit -m "Test commit"`
4. **Observe**: Husky should run ESLint on the staged file

## Troubleshooting

### Common Issues

1. **Permission denied on .husky/pre-commit**
   ```bash
   chmod +x .husky/pre-commit
   ```

2. **ESLint not found**
   - Ensure ESLint is installed in the root directory
   - Check that the path in lint-staged config is correct

3. **Linting errors block commits**
   - Fix the linting errors manually
   - Or add `--no-verify` flag to bypass hooks (not recommended)

### Manual Commands

```bash
# Run linting manually
npm run lint

# Run lint-staged manually
npx lint-staged

# Bypass pre-commit hooks (emergency only)
git commit --no-verify -m "message"
```

## Benefits

- **Automated Quality**: Ensures code quality standards before commits
- **Team Consistency**: All team members follow the same coding standards
- **Early Detection**: Catches issues before they reach the repository
- **Automatic Fixes**: ESLint fixes many issues automatically
- **CI/CD Ready**: Reduces failures in continuous integration

## Customization

### Adding More Checks

You can extend the pre-commit hook to include:

```json
{
  "lint-staged": {
    "server/**/*.js": [
      "eslint --config eslint.config.js --fix",
      "prettier --write"
    ],
    "client/**/*.{js,jsx}": [
      "eslint --config eslint.config.js --fix",
      "prettier --write"
    ],
    "**/*.{json,md}": "prettier --write"
  }
}
```

### Different ESLint Rules

Modify `eslint.config.js` to adjust rules:

```javascript
rules: {
  'no-unused-vars': 'warn',    // Change from error to warning
  'no-console': 'error',       // Disallow console statements
  'prefer-const': 'error'      // Prefer const over let
}
```

This setup ensures consistent code quality across the PromptForge project while allowing flexibility for team preferences.