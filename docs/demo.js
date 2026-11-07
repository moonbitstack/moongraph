// The demo page: the library compiled to JavaScript draws this board.
//
// Nothing here re-implements a graph algorithm. The engine returns the nodes with their
// place and their number, and the edges with the ones the algorithm chose; this file only
// puts them where the answer says.

import { graphs, run } from "./engine/moongraph.js";

const board = document.querySelector("#board");
if (board) {
  const names = JSON.parse(graphs());
  const algorithms = ["bfs", "dijkstra", "mst", "coloring", "components", "pagerank"];

  let graphName = names[0];
  let algorithm = "dijkstra";
  let source = 0;

  const graphRow = document.querySelector("#graphs");
  const algoRow = document.querySelector("#algorithms");
  const noteLine = document.querySelector("#note");

  for (const name of names) {
    const chip = document.createElement("button");
    chip.className = "chip";
    chip.textContent = name;
    chip.setAttribute("aria-pressed", String(name === graphName));
    chip.addEventListener("click", () => {
      graphName = name;
      source = 0;
      for (const other of graphRow.children) {
        other.setAttribute("aria-pressed", String(other === chip));
      }
      draw();
    });
    graphRow.append(chip);
  }

  for (const name of algorithms) {
    const chip = document.createElement("button");
    chip.className = "chip";
    chip.textContent = name;
    chip.setAttribute("aria-pressed", String(name === algorithm));
    chip.addEventListener("click", () => {
      algorithm = name;
      for (const other of algoRow.children) {
        other.setAttribute("aria-pressed", String(other === chip));
      }
      draw();
    });
    algoRow.append(chip);
  }

  function draw() {
    const answer = JSON.parse(run(graphName, algorithm, source, ""));
    const parts = [];
    parts.push('<rect x="20" y="20" width="560" height="560" fill="none" stroke="transparent"/>');
    for (const edge of answer.edges) {
      const a = answer.nodes[edge.a];
      const b = answer.nodes[edge.b];
      const klass = edge.on ? "edge on" : "edge";
      parts.push(`<line class="${klass}" x1="${a.x}" y1="${a.y}" x2="${b.x}" y2="${b.y}"/>`);
    }
    if (algorithm === "dijkstra" || algorithm === "mst") {
      for (const edge of answer.edges) {
        const a = answer.nodes[edge.a];
        const b = answer.nodes[edge.b];
        const mx = (a.x + b.x) / 2;
        const my = (a.y + b.y) / 2;
        parts.push(`<text class="edge-w" x="${mx}" y="${my - 3}" text-anchor="middle">${edge.w}</text>`);
      }
    }
    for (const node of answer.nodes) {
      if (node.i === source && (algorithm === "bfs" || algorithm === "dijkstra")) {
        parts.push(`<circle class="ring" cx="${node.x}" cy="${node.y}" r="19"/>`);
      }
      const klass = node.i === source ? "node picked" : "node";
      parts.push(`<circle class="${klass}" data-node="${node.i}" cx="${node.x}" cy="${node.y}" r="12"/>`);
      if (node.v) {
        parts.push(`<text class="label" x="${node.x}" y="${node.y + 34}" text-anchor="middle">${node.v}</text>`);
      }
    }
    board.innerHTML = parts.join("");
    for (const circle of board.querySelectorAll("[data-node]")) {
      circle.addEventListener("click", () => {
        source = Number(circle.dataset.node);
        draw();
      });
    }
    noteLine.textContent = answer.note + " Pick a node to start somewhere else.";
  }

  draw();
}
