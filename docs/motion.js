(function () {
  function reduced() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }

  function initMotion() {
    var fades = document.querySelectorAll("[data-fade]");
    var glow = document.querySelector(".hero-glow");

    if (reduced()) {
      fades.forEach(function (el) { el.classList.add("is-ready"); });
      return;
    }

    if (glow) glow.classList.add("is-animated");

    if (!("IntersectionObserver" in window)) {
      fades.forEach(function (el) { el.classList.add("is-ready"); });
      return;
    }

    var io = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-ready");
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.15 }
    );
    fades.forEach(function (el) { io.observe(el); });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initMotion);
  } else {
    initMotion();
  }
})();
