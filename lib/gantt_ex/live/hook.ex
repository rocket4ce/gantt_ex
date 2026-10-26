defmodule GanttEx.Live.Hook do
  @moduledoc """
  The only JavaScript of GanttEx: a colocated LiveView hook named
  `"GanttEx.Live.Hook.Gantt"`.

  Everything that can be done on the server is done on the server (state,
  validation, layout, dialogs, keyboard navigation). The hook only handles
  what needs the pointer position:

    * dragging bars (move, resize, progress), with snapping preview
    * drawing dependencies between bar edges
    * reordering rows in the grid
    * dragging on the timeline to create a task, or to pan the chart
    * resizing grid columns and the grid itself
    * double click to open the lightbox
    * undo / redo keyboard shortcuts (they need modifier keys)
    * fullscreen, print, scrolling and file downloads requested by the server
      (PNG images are rasterized from the server-rendered SVG)
    * reporting the visible area for smart rendering

  Each gesture ends with a single event to the server (`gx:drag`, `gx:link`,
  `gx:reorder`, `gx:create`, `gx:resize`, `gx:dblclick`, `gx:viewport`), which decides the
  outcome and re-renders the chart.

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

      const px = (el, name) => parseFloat(el.style.getPropertyValue(name)) || 0
      const clamp = (value, min, max) => Math.min(Math.max(value, min), max)
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
            }
          }
          // Ctrl/Cmd+Z and Ctrl/Cmd+Shift+Z (or Ctrl+Y): phx-keydown has no modifiers.
          this.onKeyDown = (e) => {
            if (!(e.ctrlKey || e.metaKey) || e.altKey) return
            if (e.target.closest("input, select, textarea, [contenteditable]")) return
            const key = e.key.toLowerCase()
            const event = key === "z" ? (e.shiftKey ? "redo" : "undo") : key === "y" ? "redo" : null
            if (!event) return
            e.preventDefault()
            this.push(event, {})
          }
          this.onFullscreen = () => this.toggleFullscreen()
          this.onPrint = () => window.print()

          this.el.addEventListener("pointerdown", this.onPointerDown)
          this.el.addEventListener("dblclick", this.onDblClick)
          this.el.addEventListener("keydown", this.onKeyDown)
          this.el.addEventListener("click", this.onClickCapture, true)
          this.el.addEventListener("gantt_ex:fullscreen", this.onFullscreen)
          this.el.addEventListener("gantt_ex:print", this.onPrint)

          this.handleEvent("gantt_ex:scroll", (payload) => {
            if (payload.id === this.el.id) this.scrollTo(payload)
          })
          this.handleEvent("gantt_ex:download", (payload) => {
            if (payload.id === this.el.id) this.download(payload)
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
        },

        updated() {
          this.viewport = this.el.querySelector("[data-gx-viewport]")
          this.reportViewport(false)
        },

        destroyed() {
          this.stopTracking && this.stopTracking()
          window.removeEventListener("resize", this.onResize)
        },

        // -- configuration ---------------------------------------------------

        flag(name) { return this.el.dataset[name] === "true" },
        snapPx() { return parseFloat(this.el.dataset.gxSnap) || null },
        rowHeight() { return parseFloat(getComputedStyle(this.el).getPropertyValue("--gx-row-height")) || 36 },
        push(event, payload, onReply) { this.pushEventTo(this.el, event, payload, onReply || (() => {})) },

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

        // -- pointer routing -------------------------------------------------

        pointerDown(e) {
          if (e.button !== 0 || e.target.closest("input, select, textarea, button, a, .gx-popup")) return
          const t = e.target
          const resizer = t.closest("[data-gx-resize-column]")
          if (resizer) return this.resizeColumn(e, resizer)
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
          const x0 = px(bar, "--gx-x"), w0 = px(bar, "--gx-w")
          const snap = this.snapPx()
          const snapDelta = (dx) => (snap && mode !== "progress") ? Math.round(dx / snap) * snap : dx
          const scroll0 = this.viewport.scrollLeft
          let state = {dx: 0, dw: 0, progress: null}

          this.track(e, {
            autoScroll: true,
            onMove: (dx, _dy, ev) => {
              dx = snapDelta(dx + this.viewport.scrollLeft - scroll0)
              bar.classList.add("gx-bar--dragging")
              if (mode === "move") state = {dx, dw: 0}
              if (mode === "start") { const d = Math.min(dx, w0 - MIN_BAR); state = {dx: d, dw: -d} }
              if (mode === "end") state = {dx: 0, dw: Math.max(dx, MIN_BAR - w0)}
              if (mode === "progress") {
                const rect = bar.getBoundingClientRect()
                state = {dx: 0, dw: 0, progress: clamp((ev.clientX - rect.left) / rect.width, 0, 1)}
                bar.style.setProperty("--gx-pd", `${state.progress * 100}%`)
              } else {
                bar.style.setProperty("--gx-dx", `${state.dx}px`)
                bar.style.setProperty("--gx-dw", `${state.dw}px`)
              }
            },
            onEnd: (_dx, _dy, _ev, moved) => {
              const reset = () => {
                bar.classList.remove("gx-bar--dragging")
                for (const prop of ["--gx-dx", "--gx-dw", "--gx-pd"]) bar.style.removeProperty(prop)
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
          const width0 = parseFloat(handle.dataset.gxWidth)
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
                width = clamp(width0 + dx, 32, 800)
                this.el.style.setProperty(`--gx-col-${index}`, `${width}px`)
                this.el.style.setProperty("--gx-grid-width", `${grid0 + width - width0}px`)
              }
            },
            onEnd: (_dx, _dy, _ev, moved) => {
              if (moved) this.push("gx:resize", {column, width})
            }
          })
        },

        // -- misc --------------------------------------------------------------

        dblClick(e) {
          if (e.target.closest("input, select, textarea, button, .gx-popup")) return
          const el = e.target.closest("[data-gx-bar], [data-gx-row]")
          if (el) this.push("gx:dblclick", {key: el.dataset.gxBar || el.dataset.gxRow})
        },

        toggleFullscreen() {
          if (document.fullscreenElement === this.el) document.exitFullscreen()
          else if (this.el.requestFullscreen) this.el.requestFullscreen()
          else this.el.classList.toggle("gx-root--fullscreen")
        },

        scrollTo({x, y, height}) {
          const vp = this.viewport
          const header = vp.querySelector(".gx-header")?.offsetHeight || 0
          const grid = vp.querySelector("[data-gx-grid]")?.offsetWidth || 0
          if (typeof x === "number") {
            vp.scrollTo({left: Math.max(x + grid - (vp.clientWidth + grid) / 2, 0), behavior: "smooth"})
          }
          if (typeof y === "number") {
            const visible = vp.clientHeight - header
            if (y < vp.scrollTop) vp.scrollTop = y
            else if (y + height > vp.scrollTop + visible) vp.scrollTop = y + height - visible
          }
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
