import React, { useState } from 'react';

function SearchBar({ onSearch, categories, selectedCategory, onCategoryChange }) {
  const [searchTerm, setSearchTerm] = useState('');

  const handleSearch = (e) => {
    e.preventDefault();
    onSearch(searchTerm);
  };

  return (
    <div className="search-bar">
      <form onSubmit={handleSearch}>
        <input
          type="text"
          placeholder="Search prompts..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="search-input"
        />
      </form>
      
      <div className="category-filter">
        <label>Category:</label>
        <select 
          value={selectedCategory} 
          onChange={(e) => onCategoryChange(e.target.value)}
        >
          <option value="">All Categories</option>
          {categories.map((cat) => (
            <option key={cat.category} value={cat.category}>
              {cat.category} ({cat.count})
            </option>
          ))}
        </select>
      </div>
    </div>
  );
}

export default SearchBar;