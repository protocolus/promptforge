import React, { useState, useEffect } from 'react';
import './PromptFormRenderer.css';

const PromptFormRenderer = ({ promptText, onFormDataChange, initialData = {} }) => {
  const [formData, setFormData] = useState({
    checkboxes: {},
    textareas: {}
  });

  // Parse the prompt text and extract form elements
  const parsePrompt = (text) => {
    const lines = text.split('\n');
    const elements = [];
    let currentSection = null;

    lines.forEach((line, index) => {
      const trimmedLine = line.trim();
      
      // Parse section headers (bold text)
      const headerMatch = trimmedLine.match(/^\*\*(.*?)\*\*:?$/);
      if (headerMatch) {
        currentSection = headerMatch[1];
        elements.push({
          type: 'header',
          content: currentSection,
          id: `header_${index}`
        });
        return;
      }

      // Parse checkboxes
      const checkboxMatch = trimmedLine.match(/^-\s*\[([ x])\]\s*(.+)$/);
      if (checkboxMatch) {
        const isChecked = checkboxMatch[1] === 'x';
        const label = checkboxMatch[2];
        const id = `checkbox_${currentSection || 'default'}_${index}`;
        
        elements.push({
          type: 'checkbox',
          id,
          label,
          checked: isChecked,
          section: currentSection
        });
        return;
      }

      // Parse textarea placeholders
      const textareaMatch = trimmedLine.match(/^\[(.+?)\]$/);
      if (textareaMatch) {
        const placeholder = textareaMatch[1];
        const id = `textarea_${currentSection || 'default'}_${index}`;
        
        elements.push({
          type: 'textarea',
          id,
          placeholder,
          section: currentSection
        });
        return;
      }

      // Regular text content
      if (trimmedLine && !trimmedLine.startsWith('#')) {
        elements.push({
          type: 'text',
          content: trimmedLine,
          id: `text_${index}`
        });
      }
    });

    return elements;
  };

  const elements = parsePrompt(promptText || '');

  // Initialize form data from parsed elements
  useEffect(() => {
    const newFormData = {
      checkboxes: {},
      textareas: {}
    };

    elements.forEach(element => {
      if (element.type === 'checkbox') {
        newFormData.checkboxes[element.id] = initialData.checkboxes?.[element.id] ?? element.checked;
      } else if (element.type === 'textarea') {
        newFormData.textareas[element.id] = initialData.textareas?.[element.id] ?? '';
      }
    });

    setFormData(newFormData);
  }, [promptText, initialData]);

  // Notify parent component of form data changes
  useEffect(() => {
    if (onFormDataChange) {
      onFormDataChange(formData);
    }
  }, [formData, onFormDataChange]);

  const handleCheckboxChange = (id, checked) => {
    setFormData(prev => ({
      ...prev,
      checkboxes: {
        ...prev.checkboxes,
        [id]: checked
      }
    }));
  };

  const handleTextareaChange = (id, value) => {
    setFormData(prev => ({
      ...prev,
      textareas: {
        ...prev.textareas,
        [id]: value
      }
    }));
  };

  const renderElement = (element) => {
    switch (element.type) {
      case 'header':
        return (
          <h3 key={element.id} className="form-section-header">
            {element.content}
          </h3>
        );

      case 'checkbox':
        return (
          <div key={element.id} className="form-checkbox-item">
            <label>
              <input
                type="checkbox"
                checked={formData.checkboxes[element.id] || false}
                onChange={(e) => handleCheckboxChange(element.id, e.target.checked)}
              />
              <span className="checkbox-label">{element.label}</span>
            </label>
          </div>
        );

      case 'textarea':
        return (
          <div key={element.id} className="form-textarea-item">
            <textarea
              placeholder={element.placeholder}
              value={formData.textareas[element.id] || ''}
              onChange={(e) => handleTextareaChange(element.id, e.target.value)}
              rows="3"
            />
          </div>
        );

      case 'text':
        return (
          <p key={element.id} className="form-text-content">
            {element.content}
          </p>
        );

      default:
        return null;
    }
  };

  return (
    <div className="prompt-form-renderer">
      <div className="form-content">
        {elements.map(renderElement)}
      </div>
    </div>
  );
};

export default PromptFormRenderer;