(function () {
  function reduced() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }

  function initCarousel(root) {
    var slides = Array.prototype.slice.call(root.querySelectorAll(".hero-slide"));
    if (slides.length < 2) return;

    var dotsWrap = root.querySelector(".hero-carousel-dots");
    var prevBtn = root.querySelector("[data-carousel-prev]");
    var nextBtn = root.querySelector("[data-carousel-next]");
    var index = Math.max(
      0,
      slides.findIndex(function (s) {
        return s.classList.contains("is-active");
      })
    );
    var timer = null;
    var AUTO_MS = 5200;

    function paintDots() {
      if (!dotsWrap) return;
      dotsWrap.innerHTML = "";
      slides.forEach(function (_, i) {
        var b = document.createElement("button");
        b.type = "button";
        b.className = "hero-carousel-dot";
        b.setAttribute("role", "tab");
        b.setAttribute("aria-label", "Кадр " + (i + 1));
        b.setAttribute("aria-selected", i === index ? "true" : "false");
        b.addEventListener("click", function () {
          go(i, true);
        });
        dotsWrap.appendChild(b);
      });
    }

    function go(next, user) {
      index = (next + slides.length) % slides.length;
      slides.forEach(function (slide, i) {
        var on = i === index;
        slide.classList.toggle("is-active", on);
        if (on) slide.removeAttribute("hidden");
        else slide.setAttribute("hidden", "");
      });
      if (dotsWrap) {
        Array.prototype.forEach.call(dotsWrap.children, function (dot, i) {
          dot.setAttribute("aria-selected", i === index ? "true" : "false");
        });
      }
      if (user) restart();
    }

    function next() {
      go(index + 1, false);
    }

    function stop() {
      if (timer) {
        clearInterval(timer);
        timer = null;
      }
    }

    function restart() {
      stop();
      if (reduced()) return;
      timer = setInterval(next, AUTO_MS);
    }

    if (prevBtn) {
      prevBtn.addEventListener("click", function () {
        go(index - 1, true);
      });
    }
    if (nextBtn) {
      nextBtn.addEventListener("click", function () {
        go(index + 1, true);
      });
    }

    root.addEventListener("mouseenter", stop);
    root.addEventListener("mouseleave", restart);
    root.addEventListener("focusin", stop);
    root.addEventListener("focusout", function (e) {
      if (!root.contains(e.relatedTarget)) restart();
    });

    document.addEventListener("keydown", function (e) {
      if (!root.contains(document.activeElement) && document.activeElement !== document.body) {
        return;
      }
      if (e.key === "ArrowLeft") go(index - 1, true);
      if (e.key === "ArrowRight") go(index + 1, true);
    });

    paintDots();
    go(index, false);
    restart();
  }

  function init() {
    document.querySelectorAll("[data-carousel]").forEach(initCarousel);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
