import React, { useState, useEffect } from 'react';
import PromptList from './components/PromptList';
import PromptEditor from './components/PromptEditor';
import SearchBar from './components/SearchBar';
import { getPrompts, getCategories } from './api/prompts';
import './App.css';

function App() {
  const [prompts, setPrompts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [selectedPrompt, setSelectedPrompt] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('');
  const [isCreating, setIsCreating] = useState(false);

  useEffect(() => {
    loadPrompts();
    loadCategories();
  }, [searchQuery, selectedCategory]);

  const loadPrompts = async () => {
    try {
      const data = await getPrompts({ search: searchQuery, category: selectedCategory });
      setPrompts(data);
    } catch (error) {
      console.error('Error loading prompts:', error);
    }
  };

  const loadCategories = async () => {
    try {
      const data = await getCategories();
      setCategories(data);
    } catch (error) {
      console.error('Error loading categories:', error);
    }
  };

  const handlePromptSelect = (prompt) => {
    setSelectedPrompt(prompt);
    setIsCreating(false);
  };

  const handleCreateNew = () => {
    setSelectedPrompt(null);
    setIsCreating(true);
  };

  const handleSave = () => {
    loadPrompts();
    loadCategories();
    setIsCreating(false);
  };

  const handleDelete = () => {
    loadPrompts();
    setSelectedPrompt(null);
  };

  return (
    <div className="app">
      <header className="app-header">
        <h1>PromptForge</h1>
        <p>Manage your LLM prompts with version control</p>
      </header>
      
      <div className="app-content">
        <aside className="sidebar">
          <SearchBar 
            onSearch={setSearchQuery}
            categories={categories}
            selectedCategory={selectedCategory}
            onCategoryChange={setSelectedCategory}
          />
          <button className="create-button" onClick={handleCreateNew}>
            + New Prompt
          </button>
          <PromptList 
            prompts={prompts}
            selectedPrompt={selectedPrompt}
            onSelect={handlePromptSelect}
          />
        </aside>
        
        <main className="main-content">
          {(selectedPrompt || isCreating) && (
            <PromptEditor
              prompt={selectedPrompt}
              onSave={handleSave}
              onDelete={handleDelete}
            />
          )}
          {!selectedPrompt && !isCreating && (
            <div className="empty-state">
              <h2>Select a prompt or create a new one</h2>
              <p>Your prompts are stored as markdown files in the repository</p>
            </div>
          )}
        </main>
      </div>
    </div>
  );
}

export default App;