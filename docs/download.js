(function () {
  var METRIKA_ID = 111250527;
  var GOAL_DOWNLOAD = "download_beta";

  function applyDmg(dmgUrl) {
    if (!dmgUrl) return;
    document.querySelectorAll('a[data-download="release"]').forEach(function (a) {
      a.setAttribute("href", dmgUrl);
      a.setAttribute("download", "SnapKadr.dmg");
    });
  }

  function trackDownloadClicks() {
    document.querySelectorAll('a[data-download="release"]').forEach(function (a) {
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

  // Fallback already in HTML; refresh from the release appcast on the same origin.
  // Appcast encloses zip for Sparkle; the button uses the sibling dmg.
  fetch("appcast.xml", { cache: "no-store" })
    .then(function (r) { return r.ok ? r.text() : Promise.reject(); })
    .then(function (xml) {
      var m = xml.match(/url="([^"]+SnapKadr\.zip)"/);
      if (!m) return;
      applyDmg(m[1].replace(/SnapKadr\.zip$/, "SnapKadr.dmg"));
    })
    .catch(function () {});
})();
