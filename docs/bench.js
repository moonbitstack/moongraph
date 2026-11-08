// The pathfinding bench: drag across the board to raise walls, pick a search, and watch what the
// library answers. It is the oldest idea in algorithm teaching — Red Blob Games' A* page, the
// visualisers everyone has played with — done here with the compiled library doing the work.

import { run_grid } from "./engine/moongraph.js";
import { paintRoute, paintWalls, renderBoard } from "./render.js";
import { copy, instrument } from "./menu.js";

const svg = document.querySelector("#bench");
if (svg) {
  const WIDTH = 16;
  const HEIGHT = 11;
  const CELL = 24;
  const START = HEIGHT % 2 === 0 ? (HEIGHT / 2 - 1) * WIDTH : Math.floor(HEIGHT / 2) * WIDTH + 0;
  const GOAL = START + WIDTH - 1;
  const BOARD = { width: WIDTH, height: HEIGHT, cell: CELL, start: START, goal: GOAL };

  const walls = new Set();
  let algorithm = "astar";
  let painting = false;
  let erase = false;
  let drawn = false;

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

  function clear() {
    walls.clear();
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

    if (drawn) {
      paintWalls(svg, walls);
      paintRoute(svg, BOARD, answer.path);
    } else {
      renderBoard(svg, BOARD, answer.path, walls);
      bindCells();
      drawn = true;
    }

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
        .map((entry) => {
          const live = entry.id === algorithm ? " live" : "";
          const cells = entry.cost < 0 ? "—" : entry.cells;
          return `<div class="bench-row${live}"><span class="n">${labels[entry.id]}</span><span class="c">${cells}</span><span class="t">${entry.turns ?? 0}</span></div>`;
        })
        .join("");
  }

  // Bound once, because the cells stay: the wall is a class on a cell that is already in the
  // document, so the element a drag started on survives the drag.
  function bindCells() {
    for (const cell of svg.querySelectorAll("[data-cell]")) {
      cell.addEventListener("pointerdown", (event) => {
        // The right button asks a question about the cell; it does not paint it. Neither does a
        // ctrl-click, which is a right click with a different name on a trackpad.
        if (event.button !== 0 || event.ctrlKey) return;
        event.preventDefault();
        painting = true;
        erase = walls.has(Number(cell.dataset.cell));
        toggle(Number(cell.dataset.cell));
      });
      cell.addEventListener("pointerenter", (event) => {
        // A pointer that arrives with nothing held down is a hover, whatever the last drag left
        // behind: the state is read from the pointer, not remembered from the last pointerup.
        if (event.buttons === 0) {
          painting = false;
          return;
        }
        if (painting) toggle(Number(cell.dataset.cell));
      });
    }
  }

  function toggle(id) {
    if (id === START || id === GOAL) return;
    if (erase || walls.has(id)) walls.delete(id);
    else walls.add(id);
    update();
  }

  for (const button of document.querySelectorAll("[data-bench]")) {
    button.addEventListener("click", () => {
      if (button.dataset.bench === "maze") preset();
      else clear();
    });
  }

  // The board answers a right click on a cell: raise it or clear it, keep the list of walls, or
  // start over. Everything the bench can do with the pointer, without the drag.
  svg.tabIndex = 0;
  instrument(svg, (event) => {
    const cell = event.target.closest?.("[data-cell]");
    const id = cell ? Number(cell.dataset.cell) : null;
    const items = [];
    if (id !== null) {
      const wall = walls.has(id);
      items.push({ label: wall ? "Clear this cell" : "Wall this cell", run: () => toggle(id) });
      items.push({ separator: true });
    }
    items.push({
      label: "Copy the wall list",
      hint: `${walls.size} walls`,
      run: () => copy([...walls].join(","), "wall list"),
    });
    items.push({ label: "Load the maze", run: preset });
    items.push({ label: "Clear the board", run: clear });
    return { title: id !== null ? `cell ${id}` : `${WIDTH} × ${HEIGHT} board`, items };
  });

  for (const end of ["pointerup", "pointercancel"]) {
    addEventListener(end, () => {
      painting = false;
    }, true);
  }

  preset();
}
