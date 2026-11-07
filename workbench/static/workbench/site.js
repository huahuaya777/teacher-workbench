document.addEventListener("DOMContentLoaded", () => {
  const shell = document.querySelector("#workbench-shell");
  if (!shell) return;
  const switchButtons = [...document.querySelectorAll("[data-mobile-view]")];
  function showView(view) {
    shell.dataset.activeView = view;
    for (const button of switchButtons) {
      button.setAttribute("aria-pressed", String(button.dataset.mobileView === view));
    }
  }
  showView("workspace");
  for (const button of switchButtons) {
    button.addEventListener("click", () => showView(button.dataset.mobileView));
  }
  for (const link of document.querySelectorAll("[data-workspace-link]")) {
    link.addEventListener("click", () => showView("workspace"));
  }
});
