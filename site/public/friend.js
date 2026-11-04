(() => {
  const params = new URLSearchParams(window.location.search);
  const rawHandle = params.get("handle") || "";
  const handle = rawHandle.replace(/^@/, "").toLowerCase();
  if (!/^[a-z0-9_]{3,24}$/.test(handle)) return;

  const title = document.getElementById("invite-title");
  const link = document.getElementById("open-app");
  title.textContent = `@${handle} sent you their snail mail address`;
  link.href = `snailmail://friend?handle=${encodeURIComponent(handle)}`;
})();
