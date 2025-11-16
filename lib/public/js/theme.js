// Theme management for dark/light mode
(function() {
  const THEME_KEY = 'markymark-theme';
  const LIGHT = 'light';
  const DARK = 'dark';

  let currentTheme = LIGHT;

  function initTheme() {
    // Check localStorage first, then system preference
    const savedTheme = localStorage.getItem(THEME_KEY);
    if (savedTheme) {
      currentTheme = savedTheme;
    } else if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
      currentTheme = DARK;
    }

    applyTheme(currentTheme);
    setupToggle();
  }

  function applyTheme(theme) {
    currentTheme = theme;
    document.documentElement.setAttribute('data-theme', theme);

    // Toggle highlight.js stylesheets
    const lightStyle = document.getElementById('highlight-light');
    const darkStyle = document.getElementById('highlight-dark');

    if (theme === DARK) {
      lightStyle.disabled = true;
      darkStyle.disabled = false;
    } else {
      lightStyle.disabled = false;
      darkStyle.disabled = true;
    }

    // Update toggle button icon
    const themeIcon = document.querySelector('.theme-icon');
    if (themeIcon) {
      themeIcon.textContent = theme === DARK ? '☀️' : '🌙';
    }

    // Save to localStorage
    localStorage.setItem(THEME_KEY, theme);
  }

  function toggleTheme() {
    const newTheme = currentTheme === LIGHT ? DARK : LIGHT;
    applyTheme(newTheme);

    // Re-highlight code blocks with new theme
    if (window.hljs) {
      document.querySelectorAll('pre code').forEach((block) => {
        hljs.highlightElement(block);
      });
    }
  }

  function setupToggle() {
    const toggle = document.getElementById('theme-toggle');
    if (toggle) {
      toggle.addEventListener('click', toggleTheme);
    }
  }

  // Initialize on DOM load
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initTheme);
  } else {
    initTheme();
  }

  // Export for use by other scripts
  window.MarkyTheme = {
    current: () => currentTheme,
    toggle: toggleTheme
  };
})();
