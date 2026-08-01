(function () {
  function applyDmg(dmgUrl) {
    if (!dmgUrl) return;
    document.querySelectorAll('a[data-download="beta"]').forEach(function (a) {
      a.setAttribute("href", dmgUrl);
      a.setAttribute("download", "SnapKadrBeta.dmg");
    });
  }

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
