import axios from 'axios';

const API_BASE = '/api';

export const getPrompts = async (params = {}) => {
  const response = await axios.get(`${API_BASE}/prompts`, { params });
  return response.data;
};

export const getPrompt = async (id) => {
  const response = await axios.get(`${API_BASE}/prompts/${id}`);
  return response.data;
};

export const createPrompt = async (promptData) => {
  const response = await axios.post(`${API_BASE}/prompts`, promptData);
  return response.data;
};

export const updatePrompt = async (id, promptData) => {
  const response = await axios.put(`${API_BASE}/prompts/${id}`, promptData);
  return response.data;
};

export const deletePrompt = async (id) => {
  const response = await axios.delete(`${API_BASE}/prompts/${id}`);
  return response.data;
};

export const getCategories = async () => {
  const response = await axios.get(`${API_BASE}/prompts/meta/categories`);
  return response.data;
};

export const reindexPrompts = async () => {
  const response = await axios.post(`${API_BASE}/sync/reindex`);
  return response.data;
};