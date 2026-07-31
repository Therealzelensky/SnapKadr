(function () {
  var EASE = "cubic-bezier(0.22, 1, 0.36, 1)";

  function reduced() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }

  function afterPaint(fn) {
    requestAnimationFrame(function () {
      requestAnimationFrame(fn);
    });
  }

  function activate(el) {
    if (el.classList.contains("is-ready")) return;
    var children = el.querySelectorAll("[data-reveal-child]");
    children.forEach(function (child, i) {
      child.style.setProperty("--reveal-delay", 80 + i * 90 + "ms");
    });
    var media = el.matches(".feature-media, .hero-shot")
      ? el
      : el.querySelector(".feature-media, .hero-shot");
    if (media) {
      media.style.setProperty(
        "--reveal-delay",
        children.length ? 160 + children.length * 50 + "ms" : "120ms"
      );
    }
    afterPaint(function () {
      el.classList.add("is-ready");
      children.forEach(function (child) {
        child.classList.add("is-ready");
      });
      if (media) media.classList.add("is-media-ready");
    });
  }

  function revealInstant(el) {
    el.classList.add("is-ready");
    el.querySelectorAll("[data-reveal-child]").forEach(function (child) {
      child.classList.add("is-ready");
    });
    var media = el.matches(".feature-media, .hero-shot")
      ? el
      : el.querySelector(".feature-media, .hero-shot");
    if (media) media.classList.add("is-media-ready");
  }

  function initReveals() {
    var nodes = Array.prototype.slice.call(
      document.querySelectorAll("[data-reveal], [data-fade]")
    );
    var glow = document.querySelector(".hero-glow");

    if (reduced()) {
      nodes.forEach(revealInstant);
      return;
    }

    if (glow) glow.classList.add("is-animated");

    nodes.forEach(function (el) {
      var media = el.matches(".feature-media, .hero-shot")
        ? el
        : el.querySelector(".feature-media, .hero-shot");
      if (media) media.classList.add("media-pending");
    });

    if (!("IntersectionObserver" in window)) {
      nodes.forEach(activate);
      return;
    }

    var io = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          activate(entry.target);
          io.unobserve(entry.target);
        });
      },
      { threshold: 0.08, rootMargin: "0px 0px -6% 0px" }
    );

    nodes.forEach(function (el) {
      // Hero plays on load; everything else on scroll
      if (el.classList.contains("hero-inner") || el.classList.contains("hero-shot")) {
        return;
      }
      io.observe(el);
    });

    var heroInner = document.querySelector(".hero-inner[data-reveal]");
    var heroShot = document.querySelector(".hero-shot[data-reveal]");
    if (heroInner) {
      setTimeout(function () {
        activate(heroInner);
      }, 60);
    }
    if (heroShot) {
      setTimeout(function () {
        activate(heroShot);
      }, 200);
    }

    // Safety: never leave media invisible if IO misses
    setTimeout(function () {
      document.querySelectorAll(".media-pending:not(.is-media-ready)").forEach(function (el) {
        el.classList.add("is-media-ready");
      });
      document.querySelectorAll("[data-reveal]:not(.is-ready)").forEach(function (el) {
        var rect = el.getBoundingClientRect();
        if (rect.top < window.innerHeight * 1.2) activate(el);
      });
    }, 1200);
  }

  function initParallax() {
    if (reduced()) return;
    var items = Array.prototype.slice.call(
      document.querySelectorAll("[data-parallax]")
    );
    if (!items.length) return;

    var ticking = false;

    function update() {
      ticking = false;
      var vh = window.innerHeight || 1;
      items.forEach(function (el) {
        if (!el.classList.contains("is-media-ready") && el.classList.contains("media-pending")) {
          return;
        }
        var rect = el.getBoundingClientRect();
        var mid = rect.top + rect.height / 2;
        var progress = (mid - vh / 2) / vh;
        var y = Math.max(-24, Math.min(24, progress * -28));
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
    document.documentElement.classList.add("js-motion");
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
