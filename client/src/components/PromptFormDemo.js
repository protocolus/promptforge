import React, { useState } from 'react';
import PromptFormRenderer from './PromptFormRenderer';

const PromptFormDemo = () => {
  const [formData, setFormData] = useState({});
  const [selectedPrompt, setSelectedPrompt] = useState('feature');

  const samplePrompts = {
    feature: `**Project Requirements:**
- [ ] High availability (99.9%+ uptime)
- [ ] Horizontal scalability
- [x] Security and compliance
- [ ] Real-time capabilities
- [ ] Global distribution

**Feature Description:**
[Describe what the feature should do]

**Acceptance Criteria:**
[List the requirements the feature must meet]

**Technical Constraints:**
[Any limitations or requirements to consider]`,

    debugging: `**Bug Description:**
[Describe what's happening vs what should happen]

**Performance Issues:**
- [ ] Slow response times
- [ ] High memory usage
- [x] CPU bottlenecks
- [ ] Database query performance
- [ ] Network latency

**Error Messages:**
[Paste any error messages or relevant logs]

**Recent Changes:**
[Any recent code changes that might be related]`,

    architecture: `**System Requirements:**
- [ ] Independent deployability
- [ ] Technology diversity
- [x] Team autonomy
- [ ] Fault isolation
- [ ] Scalability

**Business Requirements:**
[Describe the main features and functionality needed]

**Technical Preferences:**
[Programming languages, databases, cloud providers]

**Team Constraints:**
[Team size, experience, timeline]`
  };

  const handleFormDataChange = (data) => {
    setFormData(data);
  };

  const exportFormData = () => {
    const exportData = {
      prompt: selectedPrompt,
      timestamp: new Date().toISOString(),
      data: formData
    };
    
    const blob = new Blob([JSON.stringify(exportData, null, 2)], {
      type: 'application/json'
    });
    
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `prompt-form-${selectedPrompt}-${Date.now()}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  const loadSampleData = () => {
    const sampleData = {
      checkboxes: {
        'checkbox_Project Requirements_2': true,
        'checkbox_Project Requirements_4': true
      },
      textareas: {
        'textarea_default_8': 'This is a sample feature that will improve user experience',
        'textarea_default_11': '1. User can perform action\n2. System validates input\n3. Success message is displayed'
      }
    };
    setFormData(sampleData);
  };

  return (
    <div style={{ padding: '20px', maxWidth: '1200px', margin: '0 auto' }}>
      <h2>Prompt Form Renderer Demo</h2>
      
      <div style={{ marginBottom: '20px', display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
        <select 
          value={selectedPrompt} 
          onChange={(e) => setSelectedPrompt(e.target.value)}
          style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd' }}
        >
          <option value="feature">Feature Implementation</option>
          <option value="debugging">Bug Analysis</option>
          <option value="architecture">System Architecture</option>
        </select>
        
        <button 
          onClick={loadSampleData}
          style={{ 
            padding: '8px 16px', 
            backgroundColor: '#007bff', 
            color: 'white', 
            border: 'none', 
            borderRadius: '4px',
            cursor: 'pointer'
          }}
        >
          Load Sample Data
        </button>
        
        <button 
          onClick={exportFormData}
          style={{ 
            padding: '8px 16px', 
            backgroundColor: '#28a745', 
            color: 'white', 
            border: 'none', 
            borderRadius: '4px',
            cursor: 'pointer'
          }}
        >
          Export Form Data
        </button>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px' }}>
        <div>
          <h3>Prompt Text:</h3>
          <pre style={{ 
            backgroundColor: '#f8f9fa', 
            padding: '15px', 
            borderRadius: '6px',
            fontSize: '14px',
            lineHeight: '1.4',
            overflow: 'auto',
            border: '1px solid #e1e5e9'
          }}>
            {samplePrompts[selectedPrompt]}
          </pre>
        </div>
        
        <div>
          <h3>Rendered Form:</h3>
          <PromptFormRenderer
            promptText={samplePrompts[selectedPrompt]}
            onFormDataChange={handleFormDataChange}
            initialData={formData}
          />
        </div>
      </div>

      <div style={{ marginTop: '30px' }}>
        <h3>Form Data (JSON):</h3>
        <pre style={{ 
          backgroundColor: '#f8f9fa', 
          padding: '15px', 
          borderRadius: '6px',
          fontSize: '12px',
          overflow: 'auto',
          border: '1px solid #e1e5e9',
          maxHeight: '300px'
        }}>
          {JSON.stringify(formData, null, 2)}
        </pre>
      </div>
    </div>
  );
};

export default PromptFormDemo;