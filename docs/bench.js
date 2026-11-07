// The pathfinding bench: drag across the board to raise walls, pick a search, and watch what the
// library answers. It is the oldest idea in algorithm teaching — Red Blob Games' A* page, the
// visualisers everyone has played with — done here with the compiled library doing the work.

import { run_grid } from "./engine/moongraph.js";
import { renderBoard } from "./render.js";

const svg = document.querySelector("#bench");
if (svg) {
  const WIDTH = 16;
  const HEIGHT = 11;
  const CELL = 24;
  const START = HEIGHT % 2 === 0 ? (HEIGHT / 2 - 1) * WIDTH : Math.floor(HEIGHT / 2) * WIDTH + 0;
  const GOAL = START + WIDTH - 1;

  const walls = new Set();
  let algorithm = "astar";
  let painting = false;
  let erase = false;

  const costOut = document.querySelector("#bench-cost");
  const cellsOut = document.querySelector("#bench-cells");
  const turnsOut = document.querySelector("#bench-turns");
  const noteOut = document.querySelector("#bench-note");
  const row = document.querySelector("#bench-algos");

  const labels = {
    bfs: "bfs",
    dijkstra: "dijkstra",
    astar: "a*",
    jps: "jps",
    theta: "theta*",
  };

  for (const [id, label] of Object.entries(labels)) {
    const chip = document.createElement("button");
    chip.className = "chip";
    chip.textContent = label;
    chip.dataset.algo = id;
    chip.setAttribute("aria-pressed", String(id === algorithm));
    chip.addEventListener("click", () => {
      algorithm = id;
      for (const other of row.children) {
        other.setAttribute("aria-pressed", String(other.dataset.algo === id));
      }
      update();
    });
    row.append(chip);
  }

  function preset() {
    walls.clear();
    // A wall down the middle with two openings, the shape every pathfinding demo draws first.
    const mid = Math.floor(WIDTH / 2);
    for (let y = 0; y < HEIGHT; y++) {
      if (y === 2 || y === HEIGHT - 3) continue;
      walls.add(y * WIDTH + mid);
    }
    // A short stub, so the any-angle search has something to bend around.
    for (let x = mid + 1; x < mid + 4; x++) walls.add(3 * WIDTH + x);
    update();
  }

  function update() {
    const wallText = [...walls].join(",");
    const answer = JSON.parse(run_grid(algorithm, WIDTH, HEIGHT, wallText, START, GOAL));
    // Every search on the same board, so the difference is a column rather than a claim.
    const rows = Object.keys(labels).map((id) => {
      const each = JSON.parse(run_grid(id, WIDTH, HEIGHT, wallText, START, GOAL));
      return { id, cost: each.cost, turns: each.turns, cells: each.cells };
    });
    renderTable(rows);
    renderBoard(svg, { width: WIDTH, height: HEIGHT, cell: CELL, start: START, goal: GOAL }, answer.path, walls);
    svg.querySelectorAll(".cell").forEach((cell) => {
      cell.addEventListener("pointerdown", (event) => {
        event.preventDefault();
        painting = true;
        erase = walls.has(Number(cell.dataset.cell));
        toggle(Number(cell.dataset.cell));
      });
      cell.addEventListener("pointerenter", () => {
        if (painting) toggle(Number(cell.dataset.cell));
      });
    });
    const cost = answer.cost < 0 ? "—" : answer.cost.toFixed(2);
    if (costOut) costOut.textContent = cost;
    if (cellsOut) cellsOut.textContent = answer.cells || "0";
    if (turnsOut) turnsOut.textContent = answer.turns ?? "0";
    if (noteOut) {
      noteOut.textContent =
        answer.cost < 0
          ? "No route: the wall is closed."
          : `${labels[algorithm]} answers with ${answer.cells} cells and ${answer.turns} turns. Switch to theta* and the corners go away.`;
    }
  }

  function renderTable(rows) {
    const table = document.querySelector("#bench-table");
    if (!table) return;
    // Cells and turns, not cost: on one board every search is optimal, so the cost column
    // would say the same thing five times. What differs is how many waypoints the answer has
    // and how many times it bends.
    const head = `<div class="bench-row head"><span class="n"></span><span class="c">cells</span><span class="t">turns</span></div>`;
    table.innerHTML =
      head +
      rows
        .map((row) => {
          const live = row.id === algorithm ? " live" : "";
          const cells = row.cost < 0 ? "—" : row.cells;
          return `<div class="bench-row${live}"><span class="n">${labels[row.id]}</span><span class="c">${cells}</span><span class="t">${row.turns ?? 0}</span></div>`;
        })
        .join("");
  }

  function toggle(id) {
    if (id === START || id === GOAL) return;
    if (erase || walls.has(id)) walls.delete(id);
    else walls.add(id);
    update();
  }

  for (const button of document.querySelectorAll("[data-bench]")) {
    button.addEventListener("click", () => {
      if (button.dataset.bench === "maze") {
        preset();
      } else {
        walls.clear();
        update();
      }
    });
  }

  addEventListener("pointerup", () => {
    painting = false;
  });

  preset();
}
