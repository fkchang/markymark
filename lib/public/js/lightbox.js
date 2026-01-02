/**
 * MarkyLightbox - Simple image lightbox for Markymark
 * Opens images in a modal overlay instead of navigating away
 */
(function() {
  'use strict';

  let backdrop = null;
  let imageEl = null;
  let captionEl = null;
  let isOpen = false;

  /**
   * Create the lightbox DOM elements
   */
  function createLightbox() {
    if (backdrop) return;

    backdrop = document.createElement('div');
    backdrop.className = 'lightbox-backdrop';
    backdrop.innerHTML = `
      <button class="lightbox-close" aria-label="Close">&times;</button>
      <div class="lightbox-content">
        <img class="lightbox-image" src="" alt="">
      </div>
      <div class="lightbox-caption"></div>
    `;

    document.body.appendChild(backdrop);

    imageEl = backdrop.querySelector('.lightbox-image');
    captionEl = backdrop.querySelector('.lightbox-caption');

    // Close on backdrop click
    backdrop.addEventListener('click', function(e) {
      if (e.target === backdrop) {
        close();
      }
    });

    // Close button
    backdrop.querySelector('.lightbox-close').addEventListener('click', close);

    // Prevent clicks on image from closing
    imageEl.addEventListener('click', function(e) {
      e.stopPropagation();
    });

    // Keyboard support
    document.addEventListener('keydown', function(e) {
      if (!isOpen) return;

      if (e.key === 'Escape') {
        close();
      }
    });
  }

  /**
   * Open the lightbox with an image
   * @param {string} src - Image source URL
   * @param {string} [alt] - Optional alt text/caption
   */
  function open(src, alt) {
    createLightbox();

    imageEl.src = src;
    imageEl.alt = alt || '';

    if (alt) {
      captionEl.textContent = alt;
      captionEl.style.display = 'block';
    } else {
      captionEl.style.display = 'none';
    }

    backdrop.classList.add('active');
    document.body.classList.add('lightbox-open');
    isOpen = true;
  }

  /**
   * Close the lightbox
   */
  function close() {
    if (!backdrop) return;

    backdrop.classList.remove('active');
    document.body.classList.remove('lightbox-open');
    isOpen = false;

    // Clear image after transition
    setTimeout(function() {
      if (!isOpen && imageEl) {
        imageEl.src = '';
      }
    }, 200);
  }

  /**
   * Attach lightbox behavior to elements
   * @param {string} selector - CSS selector for elements to attach to
   */
  function attachTo(selector) {
    var elements = document.querySelectorAll(selector);

    elements.forEach(function(el) {
      // Skip if already attached
      if (el.dataset.lightboxAttached) return;
      el.dataset.lightboxAttached = 'true';

      el.addEventListener('click', function(e) {
        e.preventDefault();

        var src, alt;

        if (el.tagName === 'IMG') {
          src = el.src;
          alt = el.alt;
        } else if (el.tagName === 'A') {
          // For anchor tags, use href or data-lightbox
          src = el.dataset.lightbox || el.href;
          alt = el.textContent || el.title;
        }

        if (src) {
          open(src, alt);
        }
      });
    });
  }

  // Export public API
  window.MarkyLightbox = {
    open: open,
    close: close,
    attachTo: attachTo
  };
})();
