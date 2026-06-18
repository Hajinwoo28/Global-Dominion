const navLinks = document.querySelectorAll('.nav-menu a');
const statsItems = document.querySelectorAll('.stat-number');
const galleryCards = document.querySelectorAll('.screenshot-card');
const lightbox = document.querySelector('.lightbox');
const lightboxContent = document.querySelector('.lightbox-content');
const lightboxTitle = document.querySelector('.lightbox-title');
const lightboxClose = document.querySelector('.lightbox-close');
const trailerOverlay = document.querySelector('.trailer-player');
const trailerButton = document.querySelector('.btn-trailer');
const timeNow = Date.now();

function activateNavLink() {
  navLinks.forEach((link) => {
    const section = document.querySelector(link.getAttribute('href'));
    if (!section) return;
    const top = section.getBoundingClientRect().top;
    link.classList.toggle('active', top >= -80 && top < window.innerHeight / 2);
  });
}

function updateStats() {
  const reveal = document.querySelector('#stats-block');
  if (!reveal) return;
  const rect = reveal.getBoundingClientRect();
  if (rect.top < window.innerHeight && rect.bottom > 0) {
    statsItems.forEach((item) => {
      const endValue = Number(item.dataset.value);
      const step = Math.ceil(endValue / 60);
      let currentValue = 0;
      const interval = setInterval(() => {
        currentValue += step;
        if (currentValue >= endValue) {
          item.textContent = item.dataset.label;
          clearInterval(interval);
        } else {
          item.textContent = currentValue.toLocaleString();
        }
      }, 18);
    });
    window.removeEventListener('scroll', updateStats);
  }
}

function initSmoothScroll() {
  document.querySelectorAll('a[href^="#"]').forEach((anchor) => {
    anchor.addEventListener('click', function (e) {
      e.preventDefault();
      document.querySelector(this.getAttribute('href')).scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  });
}

function openLightbox(title, backgroundClass) {
  lightboxTitle.textContent = title;
  lightboxContent.className = `lightbox-content ${backgroundClass}`;
  lightbox.classList.add('open');
}

function closeLightbox() {
  lightbox.classList.remove('open');
}

function initGallery() {
  galleryCards.forEach((card) => {
    card.addEventListener('click', () => {
      openLightbox(card.dataset.title, card.dataset.preview);
    });
  });

  lightboxClose.addEventListener('click', closeLightbox);
  lightbox.addEventListener('click', (event) => {
    if (event.target === lightbox) closeLightbox();
  });
}

function initTrailer() {
  if (!trailerButton) return;
  trailerButton.addEventListener('click', () => {
    const video = trailerOverlay.querySelector('video');
    if (video.paused) {
      video.play();
      trailerOverlay.classList.add('playing');
    } else {
      video.pause();
      trailerOverlay.classList.remove('playing');
    }
  });
}

function init() {
  initSmoothScroll();
  initGallery();
  initTrailer();
  activateNavLink();
  window.addEventListener('scroll', activateNavLink);
  window.addEventListener('scroll', updateStats);
}

init();
