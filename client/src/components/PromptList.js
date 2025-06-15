import React from 'react';

function PromptList({ prompts, selectedPrompt, onSelect }) {
  return (
    <div className="prompt-list">
      {prompts.map((prompt) => (
        <div
          key={prompt.id}
          className={`prompt-item ${selectedPrompt?.id === prompt.id ? 'selected' : ''}`}
          onClick={() => onSelect(prompt)}
        >
          <h3>{prompt.title}</h3>
          <div className="prompt-meta">
            <span className="category">{prompt.category}</span>
            {prompt.model && <span className="model">{prompt.model}</span>}
          </div>
          <p className="prompt-preview">
            {prompt.content.substring(0, 100)}...
          </p>
        </div>
      ))}
    </div>
  );
}

export default PromptList;