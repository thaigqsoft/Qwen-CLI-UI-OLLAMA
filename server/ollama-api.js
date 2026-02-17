/**
 * Ollama API Client
 * 
 * This module provides functions to interact with Ollama REST API.
 * Supports both local and remote Ollama servers.
 */

import fetch from 'node-fetch';

// Default Ollama API base URL (can be overridden via environment variable)
const DEFAULT_OLLAMA_URL = 'http://localhost:11434';

/**
 * Get the configured Ollama API URL
 * @returns {string} Ollama API base URL
 */
export function getOllamaUrl() {
  return process.env.OLLAMA_URL || DEFAULT_OLLAMA_URL;
}

/**
 * Check if Ollama server is available
 * @returns {Promise<{available: boolean, version?: string, error?: string}>}
 */
export async function checkOllamaConnection() {
  const baseUrl = getOllamaUrl();
  
  try {
    const response = await fetch(`${baseUrl}/api/version`, {
      method: 'GET',
      headers: { 'Content-Type': 'application/json' },
      timeout: 5000
    });
    
    if (response.ok) {
      const data = await response.json();
      return {
        available: true,
        version: data.version || 'unknown'
      };
    } else {
      return {
        available: false,
        error: `HTTP ${response.status}: ${response.statusText}`
      };
    }
  } catch (error) {
    return {
      available: false,
      error: error.message || 'Connection failed'
    };
  }
}

/**
 * List all available models from Ollama
 * @returns {Promise<{success: boolean, models?: Array, error?: string}>}
 */
export async function listOllamaModels() {
  const baseUrl = getOllamaUrl();
  
  try {
    const response = await fetch(`${baseUrl}/api/tags`, {
      method: 'GET',
      headers: { 'Content-Type': 'application/json' },
      timeout: 10000
    });
    
    if (response.ok) {
      const data = await response.json();
      return {
        success: true,
        models: data.models || []
      };
    } else {
      return {
        success: false,
        error: `HTTP ${response.status}: ${response.statusText}`
      };
    }
  } catch (error) {
    return {
      success: false,
      error: error.message || 'Failed to list models'
    };
  }
}

/**
 * Send a chat message to Ollama and stream the response
 * @param {Object} options - Chat options
 * @param {string} options.model - Model name to use
 * @param {Array} options.messages - Array of chat messages
 * @param {boolean} options.stream - Whether to stream the response
 * @param {WebSocket} ws - WebSocket to send streaming responses
 * @returns {Promise<{success: boolean, response?: string, error?: string}>}
 */
export async function chatWithOllama({ model, messages, stream = true }, ws) {
  const baseUrl = getOllamaUrl();
  
  if (!model) {
    return { success: false, error: 'Model name is required' };
  }
  
  if (!messages || messages.length === 0) {
    return { success: false, error: 'Messages are required' };
  }
  
  try {
    const response = await fetch(`${baseUrl}/api/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model,
        messages,
        stream
      }),
      timeout: 300000 // 5 minutes timeout for long responses
    });
    
    if (!response.ok) {
      const errorText = await response.text();
      return {
        success: false,
        error: `HTTP ${response.status}: ${errorText}`
      };
    }
    
    if (stream && ws) {
      // Handle streaming response
      let fullResponse = '';
      
      return new Promise((resolve, reject) => {
        response.body.on('data', (chunk) => {
          try {
            const lines = chunk.toString().split('\n').filter(line => line.trim());
            
            for (const line of lines) {
              const data = JSON.parse(line);
              
              if (data.message?.content) {
                fullResponse += data.message.content;
                ws.send(JSON.stringify({
                  type: 'ollama-output',
                  data: data.message.content
                }));
              }
              
              if (data.done) {
                ws.send(JSON.stringify({
                  type: 'ollama-complete',
                  model: data.model,
                  totalDuration: data.total_duration,
                  evalCount: data.eval_count
                }));
              }
            }
          } catch (parseError) {
            // Ignore JSON parse errors for incomplete chunks
          }
        });
        
        response.body.on('end', () => {
          resolve({
            success: true,
            response: fullResponse
          });
        });
        
        response.body.on('error', (error) => {
          reject({
            success: false,
            error: error.message
          });
        });
      });
    } else {
      // Non-streaming response
      const data = await response.json();
      return {
        success: true,
        response: data.message?.content || '',
        model: data.model,
        evalCount: data.eval_count
      };
    }
  } catch (error) {
    return {
      success: false,
      error: error.message || 'Failed to chat with Ollama'
    };
  }
}

/**
 * Generate a completion with Ollama
 * @param {Object} options - Generation options
 * @param {string} options.model - Model name to use
 * @param {string} options.prompt - The prompt to complete
 * @param {boolean} options.stream - Whether to stream the response
 * @param {WebSocket} ws - WebSocket to send streaming responses
 * @returns {Promise<{success: boolean, response?: string, error?: string}>}
 */
export async function generateWithOllama({ model, prompt, stream = true }, ws) {
  const baseUrl = getOllamaUrl();
  
  if (!model) {
    return { success: false, error: 'Model name is required' };
  }
  
  if (!prompt) {
    return { success: false, error: 'Prompt is required' };
  }
  
  try {
    const response = await fetch(`${baseUrl}/api/generate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model,
        prompt,
        stream
      }),
      timeout: 300000 // 5 minutes timeout for long responses
    });
    
    if (!response.ok) {
      const errorText = await response.text();
      return {
        success: false,
        error: `HTTP ${response.status}: ${errorText}`
      };
    }
    
    if (stream && ws) {
      // Handle streaming response
      let fullResponse = '';
      
      return new Promise((resolve, reject) => {
        response.body.on('data', (chunk) => {
          try {
            const lines = chunk.toString().split('\n').filter(line => line.trim());
            
            for (const line of lines) {
              const data = JSON.parse(line);
              
              if (data.response) {
                fullResponse += data.response;
                ws.send(JSON.stringify({
                  type: 'ollama-output',
                  data: data.response
                }));
              }
              
              if (data.done) {
                ws.send(JSON.stringify({
                  type: 'ollama-complete',
                  model: data.model,
                  totalDuration: data.total_duration,
                  evalCount: data.eval_count
                }));
              }
            }
          } catch (parseError) {
            // Ignore JSON parse errors for incomplete chunks
          }
        });
        
        response.body.on('end', () => {
          resolve({
            success: true,
            response: fullResponse
          });
        });
        
        response.body.on('error', (error) => {
          reject({
            success: false,
            error: error.message
          });
        });
      });
    } else {
      // Non-streaming response
      const data = await response.json();
      return {
        success: true,
        response: data.response || '',
        model: data.model,
        evalCount: data.eval_count
      };
    }
  } catch (error) {
    return {
      success: false,
      error: error.message || 'Failed to generate with Ollama'
    };
  }
}

/**
 * Pull a model from Ollama registry
 * @param {string} modelName - Name of the model to pull
 * @param {WebSocket} ws - WebSocket to send progress updates
 * @returns {Promise<{success: boolean, error?: string}>}
 */
export async function pullOllamaModel(modelName, ws) {
  const baseUrl = getOllamaUrl();
  
  try {
    const response = await fetch(`${baseUrl}/api/pull`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: modelName,
        stream: true
      }),
      timeout: 600000 // 10 minutes timeout for model pulling
    });
    
    if (!response.ok) {
      const errorText = await response.text();
      return {
        success: false,
        error: `HTTP ${response.status}: ${errorText}`
      };
    }
    
    return new Promise((resolve, reject) => {
      response.body.on('data', (chunk) => {
        try {
          const lines = chunk.toString().split('\n').filter(line => line.trim());
          
          for (const line of lines) {
            const data = JSON.parse(line);
            
            if (ws) {
              ws.send(JSON.stringify({
                type: 'ollama-pull-progress',
                status: data.status,
                completed: data.completed,
                total: data.total,
                digest: data.digest
              }));
            }
          }
        } catch (parseError) {
          // Ignore JSON parse errors
        }
      });
      
      response.body.on('end', () => {
        resolve({ success: true });
      });
      
      response.body.on('error', (error) => {
        reject({
          success: false,
          error: error.message
        });
      });
    });
  } catch (error) {
    return {
      success: false,
      error: error.message || 'Failed to pull model'
    };
  }
}

/**
 * Get model information
 * @param {string} modelName - Name of the model
 * @returns {Promise<{success: boolean, info?: Object, error?: string}>}
 */
export async function getOllamaModelInfo(modelName) {
  const baseUrl = getOllamaUrl();
  
  try {
    const response = await fetch(`${baseUrl}/api/show`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: modelName }),
      timeout: 30000
    });
    
    if (response.ok) {
      const data = await response.json();
      return {
        success: true,
        info: data
      };
    } else {
      return {
        success: false,
        error: `HTTP ${response.status}: ${response.statusText}`
      };
    }
  } catch (error) {
    return {
      success: false,
      error: error.message || 'Failed to get model info'
    };
  }
}

export default {
  getOllamaUrl,
  checkOllamaConnection,
  listOllamaModels,
  chatWithOllama,
  generateWithOllama,
  pullOllamaModel,
  getOllamaModelInfo
};
