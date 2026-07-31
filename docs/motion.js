(function () {
  var EASE = "cubic-bezier(0.22, 1, 0.36, 1)";

  function reduced() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }

  function revealAll(root) {
    root.classList.add("is-ready");
    root.querySelectorAll("[data-reveal-child]").forEach(function (child) {
      child.classList.add("is-ready");
    });
  }

  function initReveals() {
    var nodes = document.querySelectorAll("[data-reveal], [data-fade]");
    var glow = document.querySelector(".hero-glow");

    if (reduced()) {
      nodes.forEach(revealAll);
      return;
    }

    if (glow) glow.classList.add("is-animated");

    if (!("IntersectionObserver" in window)) {
      nodes.forEach(revealAll);
      return;
    }

    var io = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          var el = entry.target;
          el.classList.add("is-ready");
          var children = el.querySelectorAll("[data-reveal-child]");
          children.forEach(function (child, i) {
            child.style.transitionDelay = 60 + i * 70 + "ms";
            child.classList.add("is-ready");
          });
          var media = el.matches(".feature-media, .hero-shot")
            ? el
            : el.querySelector(".feature-media, .hero-shot");
          if (media) {
            media.style.transitionDelay = children.length
              ? 120 + children.length * 40 + "ms"
              : "80ms";
            media.classList.add("is-media-ready");
          }
          io.unobserve(el);
        });
      },
      { threshold: 0.12, rootMargin: "0px 0px -8% 0px" }
    );

    nodes.forEach(function (el) {
      io.observe(el);
      var media = el.matches(".feature-media, .hero-shot")
        ? el
        : el.querySelector(".feature-media, .hero-shot");
      if (media) media.classList.add("media-pending");
    });

    // Hero starts almost immediately
    var heroInner = document.querySelector(".hero-inner[data-reveal]");
    if (heroInner) {
      requestAnimationFrame(function () {
        heroInner.classList.add("is-ready");
        heroInner.querySelectorAll("[data-reveal-child]").forEach(function (child, i) {
          child.style.transitionDelay = 100 + i * 90 + "ms";
          child.classList.add("is-ready");
        });
      });
    }
    var heroShot = document.querySelector(".hero-shot[data-reveal]");
    if (heroShot) {
      setTimeout(function () {
        heroShot.classList.add("is-ready");
        heroShot.classList.add("is-media-ready");
      }, 420);
    }
  }

  function initParallax() {
    if (reduced()) return;
    var items = Array.prototype.slice.call(document.querySelectorAll("[data-parallax]"));
    if (!items.length) return;

    var ticking = false;

    function update() {
      ticking = false;
      var vh = window.innerHeight || 1;
      items.forEach(function (el) {
        var rect = el.getBoundingClientRect();
        var mid = rect.top + rect.height / 2;
        var progress = (mid - vh / 2) / vh;
        var y = Math.max(-18, Math.min(18, progress * -22));
        el.style.setProperty("--parallax-y", y.toFixed(2) + "px");
      });
    }

    function onScroll() {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(update);
    }

    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll, { passive: true });
    update();
  }

  function initHeader() {
    var header = document.querySelector(".site-header");
    if (!header) return;
    var onScroll = function () {
      header.classList.toggle("is-scrolled", window.scrollY > 12);
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
  }

  function init() {
    document.documentElement.style.setProperty("--motion-ease", EASE);
    initReveals();
    initParallax();
    initHeader();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
