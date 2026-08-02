(function () {
  var METRIKA_ID = 111250527;
  var GOAL_DOWNLOAD = "download_beta";

  function applyDmg(dmgUrl) {
    if (!dmgUrl) return;
    document.querySelectorAll('a[data-download="beta"]').forEach(function (a) {
      a.setAttribute("href", dmgUrl);
      a.setAttribute("download", "SnapKadrBeta.dmg");
    });
  }

  function trackDownloadClicks() {
    document.querySelectorAll('a[data-download="beta"]').forEach(function (a) {
      if (a.dataset.metrikaBound) return;
      a.dataset.metrikaBound = "1";
      a.addEventListener("click", function () {
        if (typeof ym === "function") {
          ym(METRIKA_ID, "reachGoal", GOAL_DOWNLOAD);
        }
      });
    });
  }

  trackDownloadClicks();

  // Fallback already in HTML; refresh from live appcast on same origin.
  // Appcast encloses zip for Sparkle; CTA uses sibling dmg on the same release.
  fetch("appcast-beta.xml", { cache: "no-store" })
    .then(function (r) { return r.ok ? r.text() : Promise.reject(); })
    .then(function (xml) {
      var m = xml.match(/url="([^"]+SnapKadrBeta\.zip)"/);
      if (!m) return;
      applyDmg(m[1].replace(/SnapKadrBeta\.zip$/, "SnapKadrBeta.dmg"));
    })
    .catch(function () {});
})();
