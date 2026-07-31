(function () {
  function apply(url) {
    if (!url) return;
    document.querySelectorAll('a[data-download="beta"]').forEach(function (a) {
      a.setAttribute("href", url);
      a.setAttribute("download", "SnapKadrBeta.zip");
    });
  }

  // Fallback already in HTML; refresh from live appcast on same origin
  fetch("appcast-beta.xml", { cache: "no-store" })
    .then(function (r) { return r.ok ? r.text() : Promise.reject(); })
    .then(function (xml) {
      var m = xml.match(/url="([^"]+SnapKadrBeta\.zip)"/);
      if (m) apply(m[1]);
    })
    .catch(function () {});
})();
