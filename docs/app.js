// Two small things shared by every page: where the page is, and which theme it is in.

const root = document.documentElement;
const mark = () => root.classList.toggle("at-top", scrollY === 0);
addEventListener("scroll", mark, { passive: true });
mark();

const stored = localStorage.getItem("moongraph-theme");
if (stored) root.dataset.theme = stored;

for (const button of document.querySelectorAll("[data-theme-toggle]")) {
  button.addEventListener("click", () => {
    const next = root.dataset.theme === "dark" ? "light" : "dark";
    root.dataset.theme = next;
    localStorage.setItem("moongraph-theme", next);
    button.setAttribute("aria-label", next === "dark" ? "Switch to the light theme" : "Switch to the dark theme");
  });
}
