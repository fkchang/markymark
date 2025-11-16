// File tree management
(function() {
  let treeData = null;
  let expandedFolders = new Set();

  async function loadTree() {
    try {
      const response = await fetch('/api/tree');
      treeData = await response.json();
      renderTree();
    } catch (error) {
      console.error('Failed to load file tree:', error);
    }
  }

  function renderTree() {
    const container = document.getElementById('file-tree');
    if (!container || !treeData) return;

    container.innerHTML = '';
    renderNode(treeData, container, 0);

    // Auto-scroll to center the tree content
    setTimeout(() => {
      const scrollHeight = container.scrollHeight;
      const clientHeight = container.clientHeight;
      if (scrollHeight > clientHeight) {
        // Scroll to approximately center
        container.scrollTop = (scrollHeight - clientHeight) / 2;
      }
    }, 100);
  }

  function renderNode(node, container, depth) {
    if (node.type === 'folder') {
      renderFolder(node, container, depth);
    } else {
      renderFile(node, container, depth);
    }
  }

  function renderFolder(folder, container, depth) {
    const isExpanded = expandedFolders.has(folder.path);

    const folderDiv = document.createElement('div');
    folderDiv.className = 'tree-folder';
    folderDiv.style.paddingLeft = `${depth * 12}px`;

    const header = document.createElement('div');
    header.className = 'tree-folder-header';
    header.innerHTML = `
      <span class="tree-icon">${isExpanded ? '▼' : '▶'}</span>
      <span class="tree-label">${escapeHtml(folder.name)}</span>
    `;

    header.addEventListener('click', () => {
      if (isExpanded) {
        expandedFolders.delete(folder.path);
      } else {
        expandedFolders.add(folder.path);
      }
      renderTree();
    });

    folderDiv.appendChild(header);

    if (isExpanded && folder.children) {
      const childrenDiv = document.createElement('div');
      childrenDiv.className = 'tree-children';

      folder.children.forEach(child => {
        renderNode(child, childrenDiv, depth + 1);
      });

      folderDiv.appendChild(childrenDiv);
    }

    container.appendChild(folderDiv);
  }

  function renderFile(file, container, depth) {
    const fileDiv = document.createElement('div');
    fileDiv.className = 'tree-file';
    fileDiv.style.paddingLeft = `${depth * 12}px`;

    // Check if this is the currently selected file
    const urlParams = new URLSearchParams(window.location.search);
    const currentFile = urlParams.get('file');
    if (currentFile === file.path) {
      fileDiv.classList.add('selected');
    }

    fileDiv.innerHTML = `
      <span class="tree-icon">📄</span>
      <span class="tree-label">${escapeHtml(file.name)}</span>
    `;

    fileDiv.addEventListener('click', () => {
      window.location.href = `/view?file=${encodeURIComponent(file.path)}`;
    });

    container.appendChild(fileDiv);
  }

  function updateTree(newTreeData) {
    treeData = newTreeData;
    renderTree();
  }

  function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  // Initialize
  loadTree();

  // Export for use by app.js
  window.MarkyTree = {
    update: updateTree,
    reload: loadTree
  };
})();
