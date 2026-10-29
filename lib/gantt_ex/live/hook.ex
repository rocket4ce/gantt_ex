defmodule GanttEx.Live.Hook do
  @moduledoc """
  The only JavaScript of GanttEx: a colocated LiveView hook named
  `"GanttEx.Live.Hook.Gantt"`.

  Everything that can be done on the server is done on the server (state,
  validation, layout, dialogs, keyboard navigation). The hook only handles
  what needs the pointer position:

    * dragging bars (move, resize, progress), with snapping preview
    * drawing dependencies between bar edges
    * reordering rows in the grid, from anywhere in the row or from the drag
      handle of the `:actions` column (whose arrow keys must not scroll)
    * dragging on the timeline to create a task, or to pan the chart
    * resizing grid columns and the grid itself
    * reordering columns by dragging their header, or their item in the
      column chooser
    * double click to open the lightbox
    * opening the quick info where the bar was clicked
    * Ctrl/Cmd+click and Shift+click selection, and moving the selected bars together
    * undo / redo keyboard shortcuts (they need modifier keys)
    * fullscreen, print, scrolling, focus and file downloads requested by the
      server (PNG images are rasterized from the server-rendered SVG)
    * reporting the visible area for smart rendering

  Each gesture ends with a single event to the server (`gx:drag`, `gx:link`,
  `gx:reorder`, `gx:create`, `gx:resize`, `gx:column_move`, `gx:dblclick`,
  `gx:viewport`), which decides the outcome and re-renders the chart.

  The hook is extracted at compile time; import it in your `app.js`:

      import {hooks as ganttHooks} from "phoenix-colocated/gantt_ex"
  """
  use Phoenix.Component

  @doc false
  def hook(assigns) do
    ~H"""
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Gantt">
      const DRAG_THRESHOLD = 4
      const MIN_BAR = 6
      const POPUP_MARGIN = 8

      const px = (el, name) => parseFloat(el.style.getPropertyValue(name)) || 0
      const clamp = (value, min, max) => Math.min(Math.max(value, min), max)
      const reducedMotion = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches
      const svgEl = (tag, attrs) => {
        const el = document.createElementNS("http://www.w3.org/2000/svg", tag)
        for (const [key, value] of Object.entries(attrs)) el.setAttribute(key, value)
        return el
      }

      export default {
        mounted() {
          this.viewport = this.el.querySelector("[data-gx-viewport]")
          this.suppressClick = false

          this.onPointerDown = (e) => this.pointerDown(e)
          this.onDblClick = (e) => this.dblClick(e)
          // Swallow the click that follows a drag, before LiveView sees it.
          this.onClickCapture = (e) => {
            if (this.suppressClick) {
              e.preventDefault()
              e.stopPropagation()
              this.suppressClick = false
              return
            }
            // A plain click on a bar: the quick info opens where the bar was clicked.
            if (!(e.ctrlKey || e.metaKey || e.shiftKey)) {
              const bar = e.target.closest("[data-gx-bar]")
              if (bar && !e.target.closest(".gx-popup")) {
                bar.setAttribute("phx-value-offset", Math.round(e.clientX - bar.getBoundingClientRect().left))
              }
              return
            }
            // Ctrl/Cmd+click and Shift+click extend the selection (phx-click has no modifiers).
            if (e.target.closest("input, select, textarea, button, a, .gx-popup, .gx-popover")) return
            const el = e.target.closest("[data-gx-bar], [data-gx-row]")
            if (!el) return
            e.preventDefault()
            e.stopPropagation()
            this.push("gx:select", {key: el.dataset.gxBar || el.dataset.gxRow, mode: e.shiftKey ? "range" : "toggle"})
          }
          // Ctrl/Cmd+Z and Ctrl/Cmd+Shift+Z (or Ctrl+Y): phx-keydown has no modifiers.
          this.onKeyDown = (e) => {
            // The arrow keys of a drag handle move its row (on the server), not the scroll
            if ((e.key === "ArrowUp" || e.key === "ArrowDown") && e.target.closest("[data-gx-drag-handle]")) {
              e.preventDefault()
              return
            }
            // The arrow keys go through the items of the context menu
            const menu = e.target.closest(".gx-context-menu")
            if (menu && (e.key === "ArrowUp" || e.key === "ArrowDown")) {
              e.preventDefault()
              const items = Array.from(menu.querySelectorAll("[role=menuitem]"))
              const index = items.indexOf(document.activeElement)
              const next = e.key === "ArrowDown" ? index + 1 : index - 1
              items[(next + items.length) % items.length]?.focus()
              return
            }
            // The menu key (or Shift+F10) opens the context menu of the row in focus or selected
            if ((e.key === "ContextMenu" || (e.shiftKey && e.key === "F10")) && this.flag("gxContextMenu")) {
              if (e.target.closest("input, select, textarea, [contenteditable]")) return
              const el = e.target.closest("[data-gx-row], [data-gx-bar]") || this.el.querySelector(".gx-row--selected[data-gx-row]")
              if (!el) return
              e.preventDefault()
              const rect = el.getBoundingClientRect()
              this.openContextMenu(el.dataset.gxBar || el.dataset.gxRow, rect.left + 24, rect.bottom)
              return
            }
            if (!(e.ctrlKey || e.metaKey) || e.altKey) return
            if (e.target.closest("input, select, textarea, [contenteditable]")) return
            const key = e.key.toLowerCase()
            const event = key === "z" ? (e.shiftKey ? "redo" : "undo") : key === "y" ? "redo" : null
            if (!event) return
            e.preventDefault()
            this.push(event, {})
          }
          // A right click on a row or a bar opens its context menu (when the chart has one)
          this.onContextMenu = (e) => {
            if (!this.flag("gxContextMenu")) return
            if (e.target.closest("input, select, textarea, [contenteditable], .gx-context-menu")) return
            const el = e.target.closest("[data-gx-bar], [data-gx-row]")
            if (!el) return
            e.preventDefault()
            this.openContextMenu(el.dataset.gxBar || el.dataset.gxRow, e.clientX, e.clientY)
          }
          this.onFullscreen = () => this.toggleFullscreen()
          this.onPrint = () => window.print()
          // The menus of the toolbar (<details class="gx-menu">): one open at a
          // time, closed by Escape (back to their button) or a click or tap
          // outside them, which on a phone would leave them over the chart
          this.openMenus = () => Array.from(this.el.querySelectorAll("details.gx-menu[open]"))
          this.onMenuToggle = (e) => {
            const menu = e.target
            if (!(menu instanceof HTMLDetailsElement) || !menu.matches(".gx-menu") || !menu.open) return
            this.openMenus().forEach((other) => { if (other !== menu) other.open = false })
          }
          this.onOutsidePointer = (e) => {
            this.openMenus().forEach((menu) => { if (!menu.contains(e.target)) menu.open = false })
          }
          this.onMenuEscape = (e) => {
            if (e.key !== "Escape") return
            this.openMenus().forEach((menu) => {
              menu.open = false
              menu.querySelector("summary")?.focus()
            })
          }

          this.el.addEventListener("pointerdown", this.onPointerDown)
          this.el.addEventListener("dblclick", this.onDblClick)
          this.el.addEventListener("contextmenu", this.onContextMenu)
          this.el.addEventListener("keydown", this.onKeyDown)
          this.el.addEventListener("click", this.onClickCapture, true)
          this.el.addEventListener("toggle", this.onMenuToggle, true)
          document.addEventListener("pointerdown", this.onOutsidePointer, true)
          document.addEventListener("keydown", this.onMenuEscape)
          this.el.addEventListener("gantt_ex:fullscreen", this.onFullscreen)
          this.el.addEventListener("gantt_ex:print", this.onPrint)

          this.handleEvent("gantt_ex:scroll", (payload) => {
            if (payload.id === this.el.id) this.scrollTo(payload)
          })
          this.handleEvent("gantt_ex:download", (payload) => {
            if (payload.id === this.el.id) this.download(payload)
          })
          // Moved elements may have been replaced: give the focus back
          this.handleEvent("gantt_ex:focus", (payload) => {
            if (payload.id !== this.el.id) return
            requestAnimationFrame(() => {
              let el = null
              try { el = this.el.querySelector(payload.selector) } catch (_error) { return }
              if (el && document.activeElement !== el) el.focus()
            })
          })

          // Smart rendering: tell the server when the viewport leaves the rendered rows.
          this.onScroll = () => {
            if (this.scrollFrame) return
            this.scrollFrame = requestAnimationFrame(() => {
              this.scrollFrame = null
              this.reportViewport(false)
            })
          }
          this.onResize = () => this.reportViewport(true)
          this.viewport.addEventListener("scroll", this.onScroll, {passive: true})
          window.addEventListener("resize", this.onResize)
          this.reportViewport(true)
          this.reportWidth()

          // The visible part of the timeline changes with the page layout too (side panels...)
          this.resizeObserver = new ResizeObserver(() => {
            this.fitQuickInfo()
            this.reportWidth()
          })
          this.resizeObserver.observe(this.viewport)
        },

        updated() {
          this.viewport = this.el.querySelector("[data-gx-viewport]")
          this.reportViewport(false)
          this.fitQuickInfo()
        },

        destroyed() {
          this.stopTracking && this.stopTracking()
          this.resizeObserver.disconnect()
          window.removeEventListener("resize", this.onResize)
          document.removeEventListener("pointerdown", this.onOutsidePointer, true)
          document.removeEventListener("keydown", this.onMenuEscape)
        },

        // -- configuration ---------------------------------------------------

        flag(name) { return this.el.dataset[name] === "true" },
        snapPx() { return parseFloat(this.el.dataset.gxSnap) || null },
        rowHeight() { return parseFloat(getComputedStyle(this.el).getPropertyValue("--gx-row-height")) || 36 },
        push(event, payload, onReply) { this.pushEventTo(this.el, event, payload, onReply || (() => {})) },

        // Where the menu opens is given from the corner of the chart, with its size
        openContextMenu(key, clientX, clientY) {
          const rect = this.el.getBoundingClientRect()
          this.push("gx:context_menu", {
            key,
            x: Math.round(clientX - rect.left),
            y: Math.round(clientY - rect.top),
            width: Math.round(rect.width),
            height: Math.round(rect.height)
          })
        },

        reportViewport(force) {
          const rendered = this.el.dataset.gxWindow
          if (!rendered || !this.viewport) return
          const [first, last, count] = rendered.split(":").map(Number)
          const rowHeight = this.rowHeight()
          const top = this.viewport.scrollTop, height = this.viewport.clientHeight
          const firstVisible = Math.floor(top / rowHeight)
          const lastVisible = Math.ceil((top + height) / rowHeight)
          const margin = 8
          const nearTop = first > 0 && firstVisible < first + margin
          const nearBottom = last < count - 1 && lastVisible > last - margin
          const key = `${Math.round(top)}:${height}`
          if ((force || nearTop || nearBottom) && key !== this.lastViewport) {
            this.lastViewport = key
            this.push("gx:viewport", {top, height})
          }
        },

        // The width of the viewport: a lookahead stretches its days to fill it
        reportWidth() {
          if (!this.viewport) return
          const width = Math.round(this.viewport.clientWidth)
          if (width > 0 && width !== this.lastWidth) {
            this.lastWidth = width
            this.push("gx:width", {width})
          }
        },

        // -- pointer routing -------------------------------------------------

        pointerDown(e) {
          if (e.button !== 0) return
          const t = e.target
          const handle = t.closest("[data-gx-drag-handle]")
          if (handle) {
            if (this.flag("gxReorder") && handle.getAttribute("aria-disabled") !== "true") {
              this.reorderRow(e, handle.closest("[data-gx-row]"))
            }
            return
          }
          const resizer = t.closest("[data-gx-resize-column]")
          if (resizer) return this.resizeColumn(e, resizer)
          // Headers can be dragged from their sort button too: a click without moving still sorts
          const column = t.closest("[data-gx-column]")
          if (column && !t.closest("input, select, textarea, a, [data-gx-no-drag]")) return this.dragColumn(e, column)
          if (t.closest("input, select, textarea, button, a, .gx-popup, .gx-popover")) return
          if (this.flag("gxReadonly")) {
            if (t.closest("[data-gx-chart]")) this.pan(e)
            return
          }
          const linkPoint = t.closest("[data-gx-link-point]")
          if (linkPoint) return this.drawLink(e, linkPoint)
          const bar = t.closest("[data-gx-bar]")
          if (bar) {
            const mode = t.closest("[data-gx-progress-handle]") ? "progress"
              : t.closest("[data-gx-handle]") ? t.closest("[data-gx-handle]").dataset.gxHandle
              : bar.dataset.gxDrag
            if (mode !== "none") this.dragBar(e, bar, mode)
            return
          }
          const row = t.closest("[data-gx-row]")
          if (row && this.flag("gxReorder")) return this.reorderRow(e, row)
          const chart = t.closest("[data-gx-chart]")
          if (chart) {
            const create = this.flag("gxDragCreate") !== e.shiftKey
            return create && e.pointerType !== "touch" ? this.dragCreate(e, chart) : this.pan(e)
          }
        },

        // Calls onMove/onEnd once the pointer moved past the threshold. With
        // autoScroll, the viewport keeps scrolling while the pointer rests near an edge.
        track(e, {onMove, onEnd, threshold = DRAG_THRESHOLD, autoScroll = false}) {
          const startX = e.clientX, startY = e.clientY
          let moved = false, last = null, frame = null
          const emit = (ev) => onMove(ev.clientX - startX, ev.clientY - startY, ev)
          const tick = () => {
            frame = null
            if (last && this.edgeScroll(last)) {
              emit(last)
              frame = requestAnimationFrame(tick)
            }
          }
          const move = (ev) => {
            const dx = ev.clientX - startX, dy = ev.clientY - startY
            if (!moved && Math.hypot(dx, dy) < threshold) return
            if (!moved) this.el.classList.add("gx-root--dragging")
            moved = true
            last = ev
            ev.preventDefault()
            emit(ev)
            if (autoScroll && !frame) frame = requestAnimationFrame(tick)
          }
          const stop = (ev, cancelled) => {
            if (frame) cancelAnimationFrame(frame)
            this.stopTracking()
            this.el.classList.remove("gx-root--dragging")
            if (moved) {
              this.suppressClick = true
              setTimeout(() => { this.suppressClick = false }, 0)
            }
            onEnd && onEnd(ev.clientX - startX, ev.clientY - startY, ev, moved && !cancelled)
          }
          const up = (ev) => stop(ev, false)
          const cancel = (ev) => stop(ev, true)
          document.addEventListener("pointermove", move)
          document.addEventListener("pointerup", up)
          document.addEventListener("pointercancel", cancel)
          this.stopTracking = () => {
            document.removeEventListener("pointermove", move)
            document.removeEventListener("pointerup", up)
            document.removeEventListener("pointercancel", cancel)
            this.stopTracking = null
          }
        },

        // Scrolls the viewport when the pointer is close to its edges, faster
        // the closer it gets. Returns true if it scrolled.
        edgeScroll(ev) {
          const vp = this.viewport, rect = vp.getBoundingClientRect(), edge = 40
          const speed = (distance) => Math.ceil(((edge - distance) / edge) * 18)
          const left = vp.scrollLeft, top = vp.scrollTop
          if (ev.clientX > rect.right - edge) vp.scrollLeft += speed(rect.right - ev.clientX)
          else if (ev.clientX < rect.left + edge) vp.scrollLeft -= speed(ev.clientX - rect.left)
          if (ev.clientY > rect.bottom - edge) vp.scrollTop += speed(rect.bottom - ev.clientY)
          else if (ev.clientY < rect.top + edge) vp.scrollTop -= speed(ev.clientY - rect.top)
          return vp.scrollLeft !== left || vp.scrollTop !== top
        },

        // -- bars --------------------------------------------------------------

        dragBar(e, bar, mode) {
          if (e.shiftKey || e.ctrlKey || e.metaKey) return
          const x0 = px(bar, "--gx-x"), w0 = px(bar, "--gx-w")
          // dragging a selected bar moves the whole selection
          const group = mode === "move" && bar.classList.contains("gx-bar--selected")
            ? [...this.el.querySelectorAll(".gx-bar--selected[data-gx-drag=move]")]
            : [bar]
          const snap = this.snapPx()
          const snapDelta = (dx) => (snap && mode !== "progress") ? Math.round(dx / snap) * snap : dx
          const scroll0 = this.viewport.scrollLeft
          let state = {dx: 0, dw: 0, progress: null}

          this.track(e, {
            autoScroll: true,
            onMove: (dx, _dy, ev) => {
              dx = snapDelta(dx + this.viewport.scrollLeft - scroll0)
              group.forEach((el) => el.classList.add("gx-bar--dragging"))
              if (mode === "move") state = {dx, dw: 0}
              if (mode === "start") { const d = Math.min(dx, w0 - MIN_BAR); state = {dx: d, dw: -d} }
              if (mode === "end") state = {dx: 0, dw: Math.max(dx, MIN_BAR - w0)}
              if (mode === "progress") {
                const rect = bar.getBoundingClientRect()
                state = {dx: 0, dw: 0, progress: clamp((ev.clientX - rect.left) / rect.width, 0, 1)}
                bar.style.setProperty("--gx-pd", `${state.progress * 100}%`)
              } else {
                for (const el of group) {
                  el.style.setProperty("--gx-dx", `${state.dx}px`)
                  el.style.setProperty("--gx-dw", `${state.dw}px`)
                }
              }
            },
            onEnd: (_dx, _dy, _ev, moved) => {
              const reset = () => {
                for (const el of group) {
                  el.classList.remove("gx-bar--dragging")
                  for (const prop of ["--gx-dx", "--gx-dw", "--gx-pd"]) el.style.removeProperty(prop)
                }
              }
              if (!moved) return reset()
              this.push("gx:drag", {
                key: bar.dataset.gxBar,
                mode,
                x: x0 + state.dx,
                width: w0 + state.dw,
                progress: state.progress
              }, reset)
            }
          })
        },

        // -- links -------------------------------------------------------------

        drawLink(e, point) {
          const bar = point.closest("[data-gx-bar]")
          const chart = point.closest("[data-gx-chart]")
          const draft = chart.querySelector("[data-gx-draft]")
          const start = this.chartPoint(chart, point)
          const line = svgEl("line", {x1: start.x, y1: start.y, x2: start.x, y2: start.y, class: "gx-draft-line"})
          let hovered = null

          this.track(e, {
            threshold: 2,
            autoScroll: true,
            onMove: (_dx, _dy, ev) => {
              if (!line.isConnected) { draft.appendChild(line); this.el.classList.add("gx-root--linking") }
              const rect = chart.getBoundingClientRect()
              line.setAttribute("x2", ev.clientX - rect.left)
              line.setAttribute("y2", ev.clientY - rect.top)
              const target = document.elementFromPoint(ev.clientX, ev.clientY)?.closest("[data-gx-bar]")
              if (hovered !== target) {
                hovered && hovered.classList.remove("gx-bar--link-target")
                hovered = target && target !== bar ? target : null
                hovered && hovered.classList.add("gx-bar--link-target")
              }
            },
            onEnd: (_dx, _dy, ev, moved) => {
              line.remove()
              hovered && hovered.classList.remove("gx-bar--link-target")
              this.el.classList.remove("gx-root--linking")
              if (!moved || !hovered) return
              const targetPoint = document.elementFromPoint(ev.clientX, ev.clientY)?.closest("[data-gx-link-point]")
              const rect = hovered.getBoundingClientRect()
              const to = targetPoint ? targetPoint.dataset.gxLinkPoint
                : (ev.clientX < rect.left + rect.width / 2 ? "start" : "end")
              this.push("gx:link", {
                source: bar.dataset.gxBar,
                from: point.dataset.gxLinkPoint,
                target: hovered.dataset.gxBar,
                to
              })
            }
          })
        },

        chartPoint(chart, el) {
          const c = chart.getBoundingClientRect(), r = el.getBoundingClientRect()
          return {x: r.left + r.width / 2 - c.left, y: r.top + r.height / 2 - c.top}
        },

        // -- grid rows ---------------------------------------------------------

        reorderRow(e, row) {
          if (!row) return
          const grid = row.closest("[data-gx-grid]")
          const marker = grid.querySelector("[data-gx-drop-marker]")
          let drop = null

          const clear = () => {
            row.classList.remove("gx-row--dragging")
            grid.querySelectorAll(".gx-row--drop-inside").forEach((el) => el.classList.remove("gx-row--drop-inside"))
            marker.style.display = "none"
          }

          this.track(e, {
            threshold: 6,
            autoScroll: true,
            onMove: (_dx, _dy, ev) => {
              row.classList.add("gx-row--dragging")
              const target = document.elementFromPoint(ev.clientX, ev.clientY)?.closest("[data-gx-row]")
              grid.querySelectorAll(".gx-row--drop-inside").forEach((el) => el.classList.remove("gx-row--drop-inside"))
              if (!target || target === row || !grid.contains(target)) { drop = null; marker.style.display = "none"; return }
              const rect = target.getBoundingClientRect()
              const offset = (ev.clientY - rect.top) / rect.height
              const position = offset < 0.25 ? "before" : offset > 0.75 ? "after" : "inside"
              drop = {target: target.dataset.gxRow, position}
              if (position === "inside") {
                marker.style.display = "none"
                target.classList.add("gx-row--drop-inside")
              } else {
                marker.style.display = "block"
                marker.style.top = `${target.offsetTop + (position === "after" ? target.offsetHeight : 0) - 1}px`
              }
            },
            onEnd: (_dx, _dy, _ev, moved) => {
              clear()
              if (moved && drop) this.push("gx:reorder", {key: row.dataset.gxRow, ...drop})
            }
          })
        },

        // -- timeline ----------------------------------------------------------

        dragCreate(e, chart) {
          const draft = chart.querySelector("[data-gx-draft]")
          const rect0 = chart.getBoundingClientRect()
          const x0 = e.clientX - rect0.left
          const rowHeight = this.rowHeight()
          const top = Math.floor((e.clientY - rect0.top) / rowHeight) * rowHeight
          const box = svgEl("rect", {x: x0, y: top + 6, width: 0, height: rowHeight - 12, rx: 6, class: "gx-draft-rect"})
          let span = {x: x0, width: 0}

          this.track(e, {
            autoScroll: true,
            onMove: (_dx, _dy, ev) => {
              if (!box.isConnected) draft.appendChild(box)
              const x = ev.clientX - chart.getBoundingClientRect().left
              span = {x: Math.min(x0, x), width: Math.abs(x - x0)}
              box.setAttribute("x", span.x)
              box.setAttribute("width", span.width)
            },
            onEnd: (_dx, _dy, _ev, moved) => {
              box.remove()
              if (moved && span.width > 3) this.push("gx:create", span)
            }
          })
        },

        pan(e) {
          if (e.pointerType === "touch") return
          const left = this.viewport.scrollLeft, top = this.viewport.scrollTop
          this.track(e, {
            onMove: (dx, dy) => {
              this.el.classList.add("gx-root--panning")
              this.viewport.scrollLeft = left - dx
              this.viewport.scrollTop = top - dy
            },
            onEnd: () => this.el.classList.remove("gx-root--panning")
          })
        },

        // -- grid columns ------------------------------------------------------

        resizeColumn(e, handle) {
          e.preventDefault()
          const column = handle.dataset.gxResizeColumn
          const cell = handle.closest("[role=columnheader]")
          // a column starts from its width on the screen: the tree column may be
          // wider than its own width, as it takes the free width of the grid
          const width0 =
            column === "__grid" || !cell
              ? parseFloat(handle.dataset.gxWidth)
              : cell.getBoundingClientRect().width
          const min = parseFloat(handle.dataset.gxMinWidth || "32")
          const grid0 = px(this.el, "--gx-grid-width")
          const index = handle.dataset.gxColIndex
          let width = width0

          this.track(e, {
            threshold: 1,
            onMove: (dx) => {
              if (column === "__grid") {
                width = clamp(width0 + dx, 120, 2000)
                this.el.style.setProperty("--gx-grid-width", `${width}px`)
              } else {
                width = clamp(width0 + dx, min, 800)
                this.el.style.setProperty(`--gx-col-${index}`, `${width}px`)
                this.el.style.setProperty("--gx-grid-width", `${grid0 + width - width0}px`)
              }
            },
            onEnd: (_dx, _dy, _ev, moved) => {
              if (moved) this.push("gx:resize", {column, width, delta: width - width0})
            }
          })
        },

        // Moves a column before or after another one of the same list: the grid header
        // (horizontal) or the column chooser (vertical), with a line where it will drop.
        dragColumn(e, item) {
          const list = item.closest("[data-gx-column-list]")
          if (!list) return
          const vertical = list.dataset.gxColumnList === "vertical"
          const marker = list.querySelector("[data-gx-column-marker]")
          // Positions are taken before the dragged item starts following the pointer
          const box = list.getBoundingClientRect()
          const items = [...list.querySelectorAll("[data-gx-column]")].map((el) => {
            const r = el.getBoundingClientRect()
            return vertical
              ? {el, start: r.top - box.top + list.scrollTop, end: r.bottom - box.top + list.scrollTop}
              : {el, start: r.left - box.left, end: r.right - box.left}
          })
          let drop = null

          const hideMarker = () => { if (marker) marker.style.display = "none" }
          const clear = () => {
            item.classList.remove("gx-column--dragging")
            item.style.removeProperty("--gx-drag-offset")
            this.el.classList.remove("gx-root--moving-column")
            hideMarker()
          }

          this.track(e, {
            threshold: 5,
            onMove: (dx, dy, ev) => {
              item.classList.add("gx-column--dragging")
              this.el.classList.add("gx-root--moving-column")
              item.style.setProperty("--gx-drag-offset", `${vertical ? dy : dx}px`)
              const rect = list.getBoundingClientRect()
              const pos = vertical ? ev.clientY - rect.top + list.scrollTop : ev.clientX - rect.left
              const target = items.find((it) => pos >= it.start && pos < it.end)
              if (!target || target.el === item) { drop = null; return hideMarker() }
              const after = pos > (target.start + target.end) / 2
              drop = {target: target.el.dataset.gxColumn, position: after ? "after" : "before"}
              if (!marker) return
              marker.style.display = "block"
              marker.style[vertical ? "top" : "left"] = `${(after ? target.end : target.start) - 1}px`
            },
            onEnd: (_dx, _dy, _ev, moved) => {
              clear()
              if (moved && drop) this.push("gx:column_move", {field: item.dataset.gxColumn, ...drop})
            }
          })
        },

        // -- misc --------------------------------------------------------------

        dblClick(e) {
          if (e.target.closest("input, select, textarea, button, .gx-popup, .gx-popover")) return
          const el = e.target.closest("[data-gx-bar], [data-gx-row]")
          if (el) this.push("gx:dblclick", {key: el.dataset.gxBar || el.dataset.gxRow})
        },

        // The quick info is rendered with its left corner where the bar was clicked. Keep it in
        // the visible part of the timeline (the grid covers the chart scrolled under it): open it
        // to the left of that point when there is no room on the right, else move it in.
        fitQuickInfo() {
          const popup = this.el.querySelector(".gx-quick-info")
          if (!popup) return
          this.el.style.removeProperty("--gx-quick-info-dx")
          const vp = this.viewport
          const grid = vp.querySelector("[data-gx-grid]")
          const box = vp.getBoundingClientRect()
          const min = Math.max(box.left, grid ? grid.getBoundingClientRect().right : -Infinity) + POPUP_MARGIN
          const max = box.left + vp.clientWidth - POPUP_MARGIN
          // Layout box: the opening animation scales the popup
          const left = popup.offsetParent.getBoundingClientRect().left + popup.offsetLeft
          const width = popup.offsetWidth
          const dx = left >= min && left + width <= max ? 0
            : left - width >= min && left <= max ? -width
            : clamp(left, min, Math.max(min, max - width)) - left
          if (dx) this.el.style.setProperty("--gx-quick-info-dx", `${Math.round(dx)}px`)
        },

        toggleFullscreen() {
          if (document.fullscreenElement === this.el) document.exitFullscreen()
          else if (this.el.requestFullscreen) this.el.requestFullscreen()
          else this.el.classList.toggle("gx-root--fullscreen")
        },

        // x alone centers a date; with a width it brings a bar into view (centered when it
        // fits, else from its start) unless it is already there, and a key makes it pulse.
        scrollTo({x, y, height, width, key}) {
          const vp = this.viewport
          const header = vp.querySelector(".gx-header")?.offsetHeight || 0
          const grid = vp.querySelector("[data-gx-grid]")?.offsetWidth || 0
          const behavior = reducedMotion() ? "auto" : "smooth"
          if (typeof y === "number") {
            const visible = vp.clientHeight - header
            if (y < vp.scrollTop) vp.scrollTop = y
            else if (y + height > vp.scrollTop + visible) vp.scrollTop = y + height - visible
          }
          if (typeof x === "number") {
            // the part of the chart that the grid does not cover
            const visible = vp.clientWidth - grid
            if (typeof width !== "number") {
              vp.scrollTo({left: Math.max(x - visible / 2, 0), behavior})
            } else {
              const margin = Math.min(48, visible / 8)
              const left = vp.scrollLeft
              if (x < left + margin || x + width > left + visible - margin) {
                const target = width <= visible - 2 * margin ? x + width / 2 - visible / 2 : x - margin
                vp.scrollTo({left: Math.max(target, 0), behavior})
              }
            }
          }
          if (key) this.pulseBar(key)
        },

        pulseBar(key) {
          if (reducedMotion()) return
          const accent = getComputedStyle(this.el).getPropertyValue("--gx-accent").trim() || "#2563eb"
          this.el.querySelectorAll(`[data-gx-bar="${CSS.escape(key)}"] .gx-bar-body`).forEach((body) => {
            body.animate(
              [
                {filter: `drop-shadow(0 0 0 ${accent})`},
                {filter: `drop-shadow(0 0 7px ${accent})`, offset: 0.4},
                {filter: `drop-shadow(0 0 0 transparent)`}
              ],
              {duration: 700, iterations: 2, easing: "ease-out"}
            )
          })
        },

        async download({filename, mime, content, convert}) {
          const blob = convert === "png"
            ? await this.svgToPng(content)
            : new Blob([content], {type: `${mime};charset=utf-8`})
          const url = URL.createObjectURL(blob)
          const a = Object.assign(document.createElement("a"), {href: url, download: filename})
          document.body.appendChild(a)
          a.click()
          a.remove()
          setTimeout(() => URL.revokeObjectURL(url), 1000)
        },

        // Rasterizes the server-rendered SVG at 2x (less for huge charts).
        async svgToPng(svg) {
          const url = URL.createObjectURL(new Blob([svg], {type: "image/svg+xml;charset=utf-8"}))
          try {
            const img = new Image()
            img.src = url
            await img.decode()
            const scale = Math.min(2, 16000 / Math.max(img.naturalWidth, img.naturalHeight, 1))
            const canvas = document.createElement("canvas")
            canvas.width = Math.round(img.naturalWidth * scale)
            canvas.height = Math.round(img.naturalHeight * scale)
            const ctx = canvas.getContext("2d")
            ctx.scale(scale, scale)
            ctx.drawImage(img, 0, 0)
            return await new Promise((resolve) => canvas.toBlob(resolve, "image/png"))
          } finally {
            URL.revokeObjectURL(url)
          }
        }
      }
    </script>
    """
  end
end
