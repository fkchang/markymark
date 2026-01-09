// Main application logic
(function() {
  let currentFile = null;
  let eventSource = null;

  function init() {
    // Configure marked.js for GFM
    marked.setOptions({
      gfm: true,
      breaks: true,
      headerIds: true,
      mangle: false
    });

    // Configure mermaid
    mermaid.initialize({
      startOnLoad: false,
      theme: window.MarkyTheme && window.MarkyTheme.current() === 'dark' ? 'dark' : 'default'
    });

    // Load file from URL or default
    loadInitialFile();

    // Set up SSE connection
    connectSSE();

    // Handle browser back/forward
    window.addEventListener('popstate', () => {
      loadFileFromURL();
    });
  }

  async function loadInitialFile() {
    const urlParams = new URLSearchParams(window.location.search);
    const fileParam = urlParams.get('file');

    if (fileParam) {
      await loadFile(fileParam, false);
    } else {
      // Load default file
      await loadDefaultFile();
    }
  }

  async function loadDefaultFile() {
    try {
      const response = await fetch('/api/default-file');
      const data = await response.json();

      if (data.file) {
        // Update URL and load file
        const url = new URL(window.location);
        url.searchParams.set('file', data.file);
        window.history.replaceState({}, '', url);
        await loadFile(data.file, false);
      } else {
        showMessage('No markdown files found in this directory.');
      }
    } catch (error) {
      console.error('Failed to load default file:', error);
      showMessage('Failed to load default file.');
    }
  }

  async function loadFileFromURL() {
    const urlParams = new URLSearchParams(window.location.search);
    const fileParam = urlParams.get('file');
    if (fileParam) {
      await loadFile(fileParam, false);
    }
  }

  async function loadFile(filePath, updateHistory = true) {
    try {
      const response = await fetch(`/api/content?file=${encodeURIComponent(filePath)}`);
      if (!response.ok) {
        throw new Error('Failed to load file');
      }

      const data = await response.json();
      currentFile = data.path;

      // Update URL if needed
      if (updateHistory) {
        const url = new URL(window.location);
        url.searchParams.set('file', filePath);
        window.history.pushState({}, '', url);
      }

      // Update current path display
      const pathDisplay = document.getElementById('current-path');
      if (pathDisplay) {
        pathDisplay.textContent = filePath;
      }

      // Render markdown
      renderMarkdown(data.content);

      // Update tree selection
      if (window.MarkyTree) {
        window.MarkyTree.reload();
      }
    } catch (error) {
      console.error('Failed to load file:', error);
      showMessage('Failed to load file: ' + filePath);
    }
  }

  function renderMarkdown(markdown) {
    const container = document.getElementById('markdown-content');
    if (!container) return;

    // Convert markdown to HTML
    const html = marked.parse(markdown);
    container.innerHTML = html;

    // Process markdown inside <details> elements
    // marked.js doesn't render markdown inside HTML blocks
    processDetailsElements(container);

    // Highlight code blocks
    container.querySelectorAll('pre code').forEach((block) => {
      hljs.highlightElement(block);
    });

    // Render Mermaid diagrams
    container.querySelectorAll('code.language-mermaid').forEach(async (block, index) => {
      const code = block.textContent;
      const id = `mermaid-${Date.now()}-${index}`;

      try {
        const { svg } = await mermaid.render(id, code);
        const wrapper = document.createElement('div');
        wrapper.className = 'mermaid-diagram';
        wrapper.innerHTML = svg;
        block.parentElement.replaceWith(wrapper);
      } catch (error) {
        console.error('Mermaid rendering error:', error);
        block.parentElement.classList.add('mermaid-error');
      }
    });
  }

  function processDetailsElements(container) {
    // Find all <details> elements and render markdown content inside them
    container.querySelectorAll('details').forEach((details) => {
      const summary = details.querySelector('summary');

      // Collect all text nodes that aren't the summary
      const textNodes = [];
      details.childNodes.forEach((node) => {
        if (node.nodeType === Node.TEXT_NODE) {
          const trimmed = node.textContent.trim();
          // Only process text nodes with substantial content (not just whitespace)
          if (trimmed.length > 10) {
            textNodes.push(node);
          }
        }
      });

      // Render markdown for each text node with content
      textNodes.forEach((node) => {
        const text = node.textContent;
        const renderedHtml = marked.parse(text);
        const wrapper = document.createElement('div');
        wrapper.className = 'details-content';
        wrapper.innerHTML = renderedHtml;
        node.replaceWith(wrapper);

        // Highlight any code blocks inside
        wrapper.querySelectorAll('pre code').forEach((block) => {
          hljs.highlightElement(block);
        });
      });
    });
  }

  function showMessage(message) {
    const container = document.getElementById('markdown-content');
    if (container) {
      container.innerHTML = `<div class="message">${escapeHtml(message)}</div>`;
    }
  }

  function connectSSE() {
    eventSource = new EventSource('/stream');

    eventSource.addEventListener('file_changed', (event) => {
      const data = JSON.parse(event.data);
      if (data.path === currentFile) {
        // Current file was modified, re-render
        renderMarkdown(data.content);
      }
    });

    eventSource.addEventListener('tree_updated', (event) => {
      const tree = JSON.parse(event.data);
      if (window.MarkyTree) {
        window.MarkyTree.update(tree);
      }
    });

    eventSource.onerror = (error) => {
      console.error('SSE error:', error);
      // Reconnect after delay
      setTimeout(() => {
        connectSSE();
      }, 5000);
    };
  }

  function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  // Initialize on DOM load
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
