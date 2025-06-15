import React, { useState, useEffect } from 'react';
import Editor from '@monaco-editor/react';
import ReactMarkdown from 'react-markdown';
import { createPrompt, updatePrompt, deletePrompt } from '../api/prompts';

function PromptEditor({ prompt, onSave, onDelete }) {
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [category, setCategory] = useState('uncategorized');
  const [model, setModel] = useState('');
  const [tags, setTags] = useState([]);
  const [isPreview, setIsPreview] = useState(false);

  useEffect(() => {
    if (prompt) {
      setTitle(prompt.title);
      setContent(prompt.content);
      setCategory(prompt.category);
      setModel(prompt.model || '');
      
      const frontmatter = JSON.parse(prompt.frontmatter);
      setTags(frontmatter.tags || []);
    } else {
      // Reset for new prompt
      setTitle('');
      setContent('');
      setCategory('uncategorized');
      setModel('');
      setTags([]);
    }
  }, [prompt]);

  const handleSave = async () => {
    const promptData = {
      title,
      content,
      category,
      model: model || null,
      tags
    };

    try {
      if (prompt) {
        await updatePrompt(prompt.id, promptData);
      } else {
        await createPrompt(promptData);
      }
      onSave();
    } catch (error) {
      console.error('Error saving prompt:', error);
      alert('Failed to save prompt');
    }
  };

  const handleDelete = async () => {
    if (!prompt || !window.confirm('Are you sure you want to delete this prompt?')) {
      return;
    }

    try {
      await deletePrompt(prompt.id);
      onDelete();
    } catch (error) {
      console.error('Error deleting prompt:', error);
      alert('Failed to delete prompt');
    }
  };

  const handleTagInput = (e) => {
    if (e.key === 'Enter' && e.target.value.trim()) {
      e.preventDefault();
      setTags([...tags, e.target.value.trim()]);
      e.target.value = '';
    }
  };

  const removeTag = (index) => {
    setTags(tags.filter((_, i) => i !== index));
  };

  return (
    <div className="prompt-editor">
      <div className="editor-header">
        <input
          type="text"
          placeholder="Prompt Title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          className="title-input"
        />
        <div className="editor-actions">
          <button onClick={() => setIsPreview(!isPreview)}>
            {isPreview ? 'Edit' : 'Preview'}
          </button>
          <button onClick={handleSave} className="save-button">
            Save
          </button>
          {prompt && (
            <button onClick={handleDelete} className="delete-button">
              Delete
            </button>
          )}
        </div>
      </div>

      <div className="editor-metadata">
        <div className="metadata-field">
          <label>Category:</label>
          <input
            type="text"
            value={category}
            onChange={(e) => setCategory(e.target.value)}
            placeholder="e.g., coding, debugging"
          />
        </div>
        <div className="metadata-field">
          <label>Model:</label>
          <input
            type="text"
            value={model}
            onChange={(e) => setModel(e.target.value)}
            placeholder="e.g., claude-3-opus"
          />
        </div>
        <div className="metadata-field">
          <label>Tags:</label>
          <div className="tags-container">
            {tags.map((tag, index) => (
              <span key={index} className="tag">
                {tag}
                <button onClick={() => removeTag(index)}>×</button>
              </span>
            ))}
            <input
              type="text"
              onKeyDown={handleTagInput}
              placeholder="Add tag and press Enter"
              className="tag-input"
            />
          </div>
        </div>
      </div>

      <div className="editor-content">
        {isPreview ? (
          <div className="preview">
            <ReactMarkdown>{content}</ReactMarkdown>
          </div>
        ) : (
          <Editor
            height="100%"
            defaultLanguage="markdown"
            value={content}
            onChange={setContent}
            theme="vs-dark"
            options={{
              minimap: { enabled: false },
              fontSize: 14,
              wordWrap: 'on',
              lineNumbers: 'off'
            }}
          />
        )}
      </div>
    </div>
  );
}

export default PromptEditor;