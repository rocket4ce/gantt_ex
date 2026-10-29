defmodule GanttEx.Live.Styles do
  @moduledoc """
  The GanttEx stylesheet, shipped as colocated CSS (see `GanttEx.ColocatedCSS`).

  All classes are prefixed with `gx-` and every color, size and radius is a
  CSS custom property defined on `.gx-root`, so themes can be customized
  without touching the markup:

      .gx-root {
        --gx-accent: #0ea5e9;
        --gx-task: #0ea5e9;
        --gx-task-progress: #0369a1;
        --gx-radius: 4px;
      }

  Dark mode is applied with `theme="dark"`, or automatically with
  `theme="auto"` (the default) when the user prefers a dark color scheme or
  an ancestor has `data-theme="dark"`.
  """
  use Phoenix.Component

  @doc false
  def styles(assigns) do
    ~H"""
    <style :type={GanttEx.ColocatedCSS}>
      /* ---------------------------------------------------------------- theme */
      .gx-root {
        --gx-font-size: 13px;
        --gx-bg: #ffffff;
        --gx-surface: #f8fafc;
        --gx-surface-2: #f1f5f9;
        --gx-border: #e2e8f0;
        --gx-line: #eef2f7;
        --gx-text: #0f172a;
        --gx-muted: #64748b;
        --gx-accent: #6366f1;
        --gx-accent-strong: #4f46e5;
        --gx-accent-soft: rgba(99, 102, 241, 0.12);
        --gx-on-accent: #ffffff;
        --gx-task: #6366f1;
        --gx-task-progress: #4338ca;
        --gx-task-text: #ffffff;
        --gx-project: #0d9488;
        --gx-project-progress: #115e59;
        --gx-milestone: #f59e0b;
        --gx-milestone-border: #d97706;
        --gx-link: #94a3b8;
        --gx-weekend: rgba(148, 163, 184, 0.1);
        --gx-row-selected: rgba(99, 102, 241, 0.08);
        --gx-row-hover: rgba(15, 23, 42, 0.025);
        --gx-tooltip-bg: #0f172a;
        --gx-tooltip-text: #f8fafc;
        --gx-danger: #e11d48;
        --gx-danger-strong: #be123c;
        --gx-danger-soft: rgba(225, 29, 72, 0.1);
        --gx-warning: #f59e0b;
        --gx-warning-strong: #b45309;
        --gx-warning-soft: rgba(245, 158, 11, 0.14);
        --gx-success: #10b981;
        --gx-backdrop: rgba(15, 23, 42, 0.45);
        --gx-shadow: 0 1px 2px rgba(15, 23, 42, 0.12);
        --gx-shadow-lg: 0 24px 48px -16px rgba(15, 23, 42, 0.35), 0 2px 8px rgba(15, 23, 42, 0.06);
        --gx-radius: 6px;
        --gx-radius-lg: 12px;
        --gx-ease: cubic-bezier(0.2, 0.8, 0.2, 1);
        /* plans */
        --gx-plan: #14b8a6;
        --gx-plan-soft: rgba(20, 184, 166, 0.07);
        --gx-committed: #bbf7d0;
        --gx-committed-progress: #4ade80;
        --gx-committed-border: #22c55e;
        --gx-committed-text: #14532d;
        --gx-not-committed: #c3d2dd;
        --gx-not-committed-progress: #8ca6b9;
        --gx-not-committed-border: #7b97ab;
        --gx-not-committed-text: #1e293b;
      }

      .gx-root[data-gx-theme="dark"],
      :where([data-theme="dark"]) .gx-root[data-gx-theme="auto"] {
        --gx-bg: #111827;
        --gx-surface: #151d2c;
        --gx-surface-2: #1e293b;
        --gx-border: #273449;
        --gx-line: rgba(148, 163, 184, 0.09);
        --gx-text: #e5e7eb;
        --gx-muted: #94a3b8;
        --gx-accent: #818cf8;
        --gx-accent-strong: #a5b4fc;
        --gx-accent-soft: rgba(129, 140, 248, 0.16);
        --gx-on-accent: #0b1020;
        --gx-task: #6366f1;
        --gx-task-progress: #4338ca;
        --gx-project: #14b8a6;
        --gx-project-progress: #0f766e;
        --gx-link: #64748b;
        --gx-weekend: rgba(148, 163, 184, 0.06);
        --gx-row-selected: rgba(129, 140, 248, 0.12);
        --gx-row-hover: rgba(255, 255, 255, 0.025);
        --gx-tooltip-bg: #020617;
        --gx-tooltip-text: #e2e8f0;
        --gx-backdrop: rgba(2, 6, 23, 0.65);
        --gx-danger-strong: #fb7185;
        --gx-danger-soft: rgba(244, 63, 94, 0.16);
        --gx-warning-strong: #fbbf24;
        --gx-warning-soft: rgba(251, 191, 36, 0.14);
        --gx-success: #34d399;
        --gx-shadow: 0 1px 2px rgba(0, 0, 0, 0.4);
        --gx-shadow-lg: 0 24px 48px -16px rgba(0, 0, 0, 0.7), 0 0 0 1px rgba(148, 163, 184, 0.08);
        --gx-plan: #2dd4bf;
        --gx-plan-soft: rgba(45, 212, 191, 0.08);
        --gx-committed: #14532d;
        --gx-committed-progress: #16a34a;
        --gx-committed-border: #22c55e;
        --gx-committed-text: #dcfce7;
        --gx-not-committed: #334155;
        --gx-not-committed-progress: #475569;
        --gx-not-committed-border: #64748b;
        --gx-not-committed-text: #e2e8f0;
      }

      @media (prefers-color-scheme: dark) {
        .gx-root[data-gx-theme="auto"]:not(:where([data-theme="light"] *)) {
          --gx-bg: #111827;
          --gx-surface: #151d2c;
          --gx-surface-2: #1e293b;
          --gx-border: #273449;
          --gx-line: rgba(148, 163, 184, 0.09);
          --gx-text: #e5e7eb;
          --gx-muted: #94a3b8;
          --gx-accent: #818cf8;
          --gx-accent-strong: #a5b4fc;
          --gx-accent-soft: rgba(129, 140, 248, 0.16);
          --gx-on-accent: #0b1020;
          --gx-project: #14b8a6;
          --gx-project-progress: #0f766e;
          --gx-link: #64748b;
          --gx-weekend: rgba(148, 163, 184, 0.06);
          --gx-row-selected: rgba(129, 140, 248, 0.12);
          --gx-row-hover: rgba(255, 255, 255, 0.025);
          --gx-tooltip-bg: #020617;
          --gx-tooltip-text: #e2e8f0;
          --gx-backdrop: rgba(2, 6, 23, 0.65);
          --gx-danger-strong: #fb7185;
          --gx-danger-soft: rgba(244, 63, 94, 0.16);
          --gx-warning-strong: #fbbf24;
          --gx-warning-soft: rgba(251, 191, 36, 0.14);
          --gx-success: #34d399;
          --gx-shadow: 0 1px 2px rgba(0, 0, 0, 0.4);
          --gx-shadow-lg: 0 24px 48px -16px rgba(0, 0, 0, 0.7), 0 0 0 1px rgba(148, 163, 184, 0.08);
          --gx-plan: #2dd4bf;
          --gx-plan-soft: rgba(45, 212, 191, 0.08);
          --gx-committed: #14532d;
          --gx-committed-progress: #16a34a;
          --gx-committed-border: #22c55e;
          --gx-committed-text: #dcfce7;
          --gx-not-committed: #334155;
          --gx-not-committed-progress: #475569;
          --gx-not-committed-border: #64748b;
          --gx-not-committed-text: #e2e8f0;
        }
      }

      /* --------------------------------------------------------------- layout */
      .gx-root {
        position: relative;
        display: flex;
        flex-direction: column;
        font-size: var(--gx-font-size);
        line-height: 1.4;
        color: var(--gx-text);
        background: var(--gx-bg);
        border: 1px solid var(--gx-border);
        border-radius: var(--gx-radius-lg);
        overflow: hidden;
        isolation: isolate;
        -webkit-font-smoothing: antialiased;
      }

      .gx-root *,
      .gx-root *::before,
      .gx-root *::after {
        box-sizing: border-box;
      }

      .gx-root:fullscreen,
      .gx-root--fullscreen {
        position: fixed;
        inset: 0;
        z-index: 900;
        border: 0;
        border-radius: 0;
      }

      .gx-root:fullscreen .gx-viewport,
      .gx-root--fullscreen .gx-viewport {
        flex: 1;
        height: auto;
      }

      .gx-root--dragging,
      .gx-root--dragging * {
        user-select: none;
        -webkit-user-select: none;
      }

      .gx-root--panning .gx-chart {
        cursor: grabbing;
      }

      .gx-viewport {
        position: relative;
        height: var(--gx-height, 640px);
        overflow: auto;
        overscroll-behavior: contain;
        outline: none;
        scrollbar-width: thin;
        scrollbar-color: var(--gx-border) transparent;
      }

      .gx-viewport:focus-visible {
        box-shadow: inset 0 0 0 2px var(--gx-accent-soft);
      }

      .gx-canvas {
        position: relative;
        display: flex;
        flex-direction: column;
        min-width: 100%;
        min-height: 100%;
      }

      .gx-header {
        position: sticky;
        top: 0;
        z-index: 30;
        display: flex;
        background: var(--gx-surface);
        border-bottom: 1px solid var(--gx-border);
      }

      .gx-body {
        position: relative;
        display: flex;
        flex: 1;
      }

      .gx-truncate {
        min-width: 0;
        overflow: hidden;
        white-space: nowrap;
        text-overflow: ellipsis;
      }

      .gx-sr-only {
        position: absolute;
        width: 1px;
        height: 1px;
        padding: 0;
        margin: -1px;
        overflow: hidden;
        clip-path: inset(50%);
        white-space: nowrap;
        border: 0;
      }

      .gx-icon {
        width: 16px;
        height: 16px;
        flex: none;
      }

      /* -------------------------------------------------------------- toolbar */
      .gx-toolbar {
        position: relative;
        display: flex;
        flex-wrap: wrap;
        align-items: center;
        gap: 8px;
        padding: 8px 10px;
        background: var(--gx-surface);
        border-bottom: 1px solid var(--gx-border);
      }

      .gx-toolbar-group {
        display: inline-flex;
        align-items: center;
        gap: 2px;
      }

      .gx-toolbar-spacer {
        flex: 1;
      }

      .gx-segmented {
        padding: 2px;
        background: var(--gx-surface-2);
        border: 1px solid var(--gx-border);
        border-radius: 9px;
      }

      .gx-segment {
        height: 26px;
        padding: 0 10px;
        font: inherit;
        font-size: 12px;
        font-weight: 500;
        color: var(--gx-muted);
        background: transparent;
        border: 0;
        border-radius: 7px;
        cursor: pointer;
        transition: background-color 0.15s, color 0.15s, box-shadow 0.15s;
      }

      .gx-segment:hover {
        color: var(--gx-text);
      }

      .gx-segment--active {
        color: var(--gx-text);
        background: var(--gx-bg);
        box-shadow: var(--gx-shadow);
      }

      .gx-btn {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 6px;
        height: 30px;
        padding: 0 10px;
        font: inherit;
        font-weight: 500;
        color: var(--gx-text);
        white-space: nowrap;
        background: transparent;
        border: 1px solid transparent;
        border-radius: 8px;
        cursor: pointer;
        transition: background-color 0.15s, border-color 0.15s, color 0.15s, transform 0.1s, box-shadow 0.15s;
      }

      .gx-btn:hover {
        background: var(--gx-surface-2);
      }

      .gx-btn:active {
        transform: translateY(1px);
      }

      .gx-btn:focus-visible,
      .gx-segment:focus-visible,
      .gx-sort:focus-visible,
      .gx-toggle:focus-visible,
      .gx-add:focus-visible {
        outline: 2px solid var(--gx-accent);
        outline-offset: 1px;
      }

      .gx-btn:disabled {
        opacity: 0.4;
        cursor: not-allowed;
        transform: none;
      }

      .gx-btn--icon {
        width: 30px;
        padding: 0;
        color: var(--gx-muted);
      }

      .gx-btn--icon:hover {
        color: var(--gx-text);
      }

      .gx-btn--primary {
        color: var(--gx-on-accent);
        background: var(--gx-accent);
        box-shadow: 0 1px 2px rgba(79, 70, 229, 0.3), inset 0 1px 0 rgba(255, 255, 255, 0.15);
      }

      .gx-btn--primary:hover {
        background: var(--gx-accent-strong);
      }

      .gx-btn--danger {
        color: #ffffff;
        background: var(--gx-danger);
      }

      .gx-btn--danger:hover {
        background: #be123c;
      }

      .gx-btn--danger-ghost {
        color: var(--gx-danger);
      }

      .gx-btn--danger-ghost:hover {
        background: var(--gx-danger-soft);
      }

      .gx-menu {
        position: relative;
      }

      .gx-menu > summary {
        list-style: none;
      }

      .gx-menu > summary::-webkit-details-marker {
        display: none;
      }

      .gx-menu[open] > summary {
        background: var(--gx-surface-2);
      }

      .gx-menu-list {
        position: absolute;
        top: calc(100% + 6px);
        right: 0;
        z-index: 60;
        display: flex;
        flex-direction: column;
        min-width: 200px;
        padding: 4px;
        background: var(--gx-bg);
        border: 1px solid var(--gx-border);
        border-radius: 10px;
        box-shadow: var(--gx-shadow-lg);
        animation: gx-pop 0.14s var(--gx-ease);
      }

      .gx-menu-item {
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 7px 10px;
        font: inherit;
        color: var(--gx-text);
        text-align: left;
        background: transparent;
        border: 0;
        border-radius: 6px;
        cursor: pointer;
      }

      .gx-menu-item:hover {
        background: var(--gx-surface-2);
      }

      .gx-btn--small {
        width: 26px;
        height: 26px;
      }

      .gx-text-btn {
        display: inline-flex;
        align-items: center;
        gap: 4px;
        padding: 3px 7px;
        font: inherit;
        font-size: 12px;
        font-weight: 600;
        color: var(--gx-accent-strong);
        white-space: nowrap;
        background: transparent;
        border: 0;
        border-radius: 6px;
        cursor: pointer;
        transition: background-color 0.15s, color 0.15s;
      }

      .gx-text-btn:hover {
        background: var(--gx-accent-soft);
      }

      .gx-text-btn:focus-visible {
        outline: 2px solid var(--gx-accent);
        outline-offset: 1px;
      }

      .gx-badge {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-width: 18px;
        height: 18px;
        padding: 0 5px;
        margin-right: -2px;
        font-size: 11px;
        font-weight: 700;
        line-height: 1;
        color: var(--gx-on-accent);
        background: var(--gx-accent);
        border-radius: 999px;
        font-variant-numeric: tabular-nums;
        animation: gx-pop 0.18s var(--gx-ease);
      }

      /* ---------------------------------------------------------------- search */
      .gx-search {
        position: relative;
        display: inline-flex;
        align-items: center;
        width: 200px;
        height: 30px;
        margin: 0;
        color: var(--gx-muted);
        background: var(--gx-bg);
        border: 1px solid var(--gx-border);
        border-radius: 8px;
        transition: width 0.2s var(--gx-ease), border-color 0.15s, box-shadow 0.15s;
      }

      .gx-search:hover {
        border-color: color-mix(in srgb, var(--gx-border) 50%, var(--gx-muted));
      }

      .gx-search:focus-within,
      .gx-search--active {
        width: 240px;
      }

      .gx-search:focus-within {
        border-color: var(--gx-accent);
        box-shadow: 0 0 0 3px var(--gx-accent-soft);
      }

      .gx-search-icon {
        position: absolute;
        left: 9px;
        width: 14px;
        height: 14px;
        pointer-events: none;
      }

      .gx-search-input {
        width: 100%;
        height: 100%;
        min-width: 0;
        padding: 0 28px 0 30px;
        font: inherit;
        color: var(--gx-text);
        background: transparent;
        border: 0;
        border-radius: inherit;
        outline: none;
        appearance: none;
        -webkit-appearance: none;
      }

      .gx-search-input::placeholder,
      .gx-combobox-input::placeholder {
        color: var(--gx-muted);
        opacity: 0.8;
      }

      .gx-search-input::-webkit-search-cancel-button,
      .gx-combobox-input::-webkit-search-cancel-button {
        display: none;
      }

      .gx-search-clear {
        position: absolute;
        right: 4px;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 22px;
        height: 22px;
        padding: 0;
        color: var(--gx-muted);
        background: transparent;
        border: 0;
        border-radius: 6px;
        cursor: pointer;
      }

      .gx-search-clear:hover {
        color: var(--gx-text);
        background: var(--gx-surface-2);
      }

      .gx-search-clear .gx-icon {
        width: 14px;
        height: 14px;
      }

      /* -------------------------------------------------------------- popovers */
      /* Positioned against the toolbar, so they stay inside the chart */
      .gx-popover {
        position: absolute;
        top: calc(100% + 4px);
        right: 10px;
        z-index: 60;
        display: flex;
        flex-direction: column;
        max-height: min(560px, calc(var(--gx-height, 640px) - 16px));
        color: var(--gx-text);
        background: var(--gx-bg);
        border: 1px solid var(--gx-border);
        border-radius: var(--gx-radius-lg);
        box-shadow: var(--gx-shadow-lg);
        animation: gx-pop 0.16s var(--gx-ease);
      }

      .gx-popover-header {
        display: flex;
        flex: none;
        align-items: center;
        gap: 6px;
        padding: 10px 10px 10px 16px;
        border-bottom: 1px solid var(--gx-line);
      }

      .gx-popover-title {
        flex: 1;
        margin: 0;
        font-size: 13px;
        font-weight: 650;
        letter-spacing: -0.005em;
      }

      .gx-filters {
        width: min(640px, calc(100% - 20px));
      }

      .gx-filters-form {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
        align-items: start;
        gap: 18px 22px;
        min-height: 0;
        padding: 14px 16px 18px;
        overflow: auto;
        overscroll-behavior: contain;
        scrollbar-width: thin;
      }

      .gx-filter {
        min-width: 0;
        padding: 0;
        margin: 0;
        border: 0;
      }

      .gx-filter-legend {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 8px;
        width: 100%;
        min-height: 22px;
        padding: 0;
        margin-bottom: 8px;
        font-size: 11px;
        font-weight: 600;
        letter-spacing: 0.02em;
        text-transform: uppercase;
        color: var(--gx-muted);
      }

      .gx-filter-legend .gx-text-btn {
        text-transform: none;
        letter-spacing: normal;
      }

      .gx-chips {
        display: flex;
        flex-wrap: wrap;
        gap: 6px;
      }

      .gx-chip-check {
        position: relative;
        display: inline-flex;
        align-items: center;
        gap: 6px;
        height: 28px;
        padding: 0 11px;
        font-size: 12px;
        font-weight: 500;
        color: var(--gx-text);
        white-space: nowrap;
        background: var(--gx-bg);
        border: 1px solid var(--gx-border);
        border-radius: 999px;
        cursor: pointer;
        user-select: none;
        transition: background-color 0.15s, border-color 0.15s, color 0.15s, transform 0.1s;
      }

      .gx-chip-check:hover {
        border-color: color-mix(in srgb, var(--gx-border) 40%, var(--gx-muted));
      }

      .gx-chip-check:active {
        transform: scale(0.97);
      }

      .gx-chip-check input,
      .gx-option input {
        position: absolute;
        width: 1px;
        height: 1px;
        margin: 0;
        opacity: 0;
        pointer-events: none;
      }

      .gx-chip-check:has(input:checked),
      .gx-chip-check--on {
        color: var(--gx-accent-strong);
        background: var(--gx-accent-soft);
        border-color: color-mix(in srgb, var(--gx-accent) 55%, transparent);
      }

      .gx-chip-check:has(input:focus-visible),
      .gx-option:has(input:focus-visible) {
        outline: 2px solid var(--gx-accent);
        outline-offset: 1px;
      }

      .gx-chip-check .gx-type-dot {
        margin: 0;
      }

      .gx-dot {
        flex: none;
        width: 8px;
        height: 8px;
        background: var(--gx-dot, var(--gx-muted));
        border-radius: 50%;
        box-shadow: 0 0 0 2px color-mix(in srgb, var(--gx-dot, var(--gx-muted)) 18%, transparent);
      }

      .gx-option-icon {
        display: inline-flex;
        flex: none;
      }

      .gx-option-icon .gx-icon {
        width: 14px;
        height: 14px;
      }

      .gx-option-icon--blocked {
        color: var(--gx-danger);
      }

      .gx-option-icon--restricted {
        color: var(--gx-warning);
      }

      .gx-avatar {
        flex: none;
        width: 20px;
        height: 20px;
        object-fit: cover;
        background: var(--gx-surface-2);
        border-radius: 50%;
        box-shadow: 0 0 0 1px var(--gx-line);
      }

      .gx-filter-dates {
        display: flex;
        gap: 10px;
      }

      .gx-filter-dates .gx-field {
        gap: 4px;
      }

      .gx-filter-dates .gx-field > span {
        font-size: 12px;
        color: var(--gx-muted);
      }

      .gx-input--small {
        height: 32px;
        padding: 0 8px;
      }

      .gx-filter .gx-error {
        margin-top: 6px;
      }

      /* custom filters: chips, search and options */
      .gx-combobox-chips {
        margin-bottom: 8px;
      }

      .gx-chip {
        display: inline-flex;
        align-items: center;
        gap: 5px;
        max-width: 100%;
        height: 26px;
        padding: 0 3px 0 9px;
        font-size: 12px;
        font-weight: 500;
        color: var(--gx-text);
        background: var(--gx-surface-2);
        border: 1px solid transparent;
        border-radius: 999px;
        animation: gx-pop 0.14s var(--gx-ease);
      }

      .gx-chip:has(> .gx-avatar) {
        padding-left: 3px;
      }

      .gx-chip .gx-avatar {
        width: 18px;
        height: 18px;
      }

      .gx-chip-remove {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        flex: none;
        width: 20px;
        height: 20px;
        padding: 0;
        color: var(--gx-muted);
        background: transparent;
        border: 0;
        border-radius: 50%;
        cursor: pointer;
        transition: background-color 0.15s, color 0.15s;
      }

      .gx-chip-remove:hover {
        color: var(--gx-text);
        background: color-mix(in srgb, var(--gx-muted) 20%, transparent);
      }

      .gx-chip-remove:focus-visible {
        outline: 2px solid var(--gx-accent);
      }

      .gx-chip-remove .gx-icon {
        width: 12px;
        height: 12px;
      }

      .gx-combobox-search {
        position: relative;
        display: flex;
        align-items: center;
        margin-bottom: 6px;
        color: var(--gx-muted);
      }

      .gx-combobox-search > .gx-icon {
        position: absolute;
        left: 9px;
        width: 14px;
        height: 14px;
        pointer-events: none;
      }

      .gx-combobox-input {
        width: 100%;
        height: 32px;
        padding: 0 10px 0 30px;
        font: inherit;
        color: var(--gx-text);
        background: var(--gx-bg);
        border: 1px solid var(--gx-border);
        border-radius: 8px;
        outline: none;
        appearance: none;
        -webkit-appearance: none;
        transition: border-color 0.15s, box-shadow 0.15s;
      }

      .gx-combobox-input:focus {
        border-color: var(--gx-accent);
        box-shadow: 0 0 0 3px var(--gx-accent-soft);
      }

      .gx-options {
        display: flex;
        flex-direction: column;
        gap: 1px;
        max-height: 196px;
        padding: 4px;
        overflow: auto;
        overscroll-behavior: contain;
        background: var(--gx-surface);
        border: 1px solid var(--gx-line);
        border-radius: 10px;
        scrollbar-width: thin;
      }

      .gx-option {
        position: relative;
        display: flex;
        flex: none;
        align-items: center;
        gap: 8px;
        min-height: 32px;
        padding: 4px 8px;
        border-radius: 7px;
        cursor: pointer;
        user-select: none;
        transition: background-color 0.12s;
      }

      .gx-option:hover {
        background: var(--gx-row-hover);
        background: color-mix(in srgb, var(--gx-text) 5%, transparent);
      }

      .gx-option-check {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        flex: none;
        width: 16px;
        height: 16px;
        color: transparent;
        background: var(--gx-bg);
        border: 1.5px solid color-mix(in srgb, var(--gx-border) 30%, var(--gx-muted));
        border-radius: 4px;
        transition: background-color 0.15s, border-color 0.15s, color 0.15s;
      }

      .gx-option-check--radio {
        border-radius: 50%;
      }

      .gx-option-check .gx-icon {
        width: 11px;
        height: 11px;
        stroke-width: 3;
      }

      .gx-option:has(input:checked) .gx-option-check,
      .gx-option--checked .gx-option-check {
        color: var(--gx-on-accent);
        background: var(--gx-accent);
        border-color: var(--gx-accent);
      }

      .gx-option-text {
        display: flex;
        flex-direction: column;
        min-width: 0;
        line-height: 1.25;
      }

      .gx-option-hint {
        font-size: 11px;
        color: var(--gx-muted);
      }

      .gx-options-empty,
      .gx-options-more {
        margin: 0;
        padding: 6px 8px;
        font-size: 12px;
        color: var(--gx-muted);
      }

      .gx-options-more {
        font-style: italic;
      }

      /* ------------------------------------------------------- column chooser */
      .gx-columns {
        width: min(300px, calc(100% - 20px));
      }

      .gx-columns-form {
        min-height: 0;
        padding: 6px;
        overflow: auto;
        overscroll-behavior: contain;
        scrollbar-width: thin;
      }

      .gx-column-list {
        position: relative;
      }

      .gx-column-list ul {
        display: flex;
        flex-direction: column;
        gap: 1px;
        padding: 0;
        margin: 0;
        list-style: none;
      }

      .gx-column-item {
        position: relative;
        display: flex;
        align-items: center;
        gap: 2px;
        padding: 0 4px 0 2px;
        border-radius: 8px;
        transition: background-color 0.12s;
      }

      .gx-column-item:hover {
        background: color-mix(in srgb, var(--gx-text) 4%, transparent);
      }

      .gx-column-item .gx-option {
        flex: 1;
        min-width: 0;
      }

      .gx-column-item .gx-option:hover {
        background: transparent;
      }

      .gx-column-item--hidden .gx-truncate {
        color: var(--gx-muted);
      }

      .gx-column-item .gx-option:has(input:disabled) {
        cursor: default;
      }

      .gx-column-item .gx-option:has(input:disabled) .gx-option-check {
        opacity: 0.55;
      }

      .gx-column-grip {
        display: inline-flex;
        flex: none;
        padding: 4px 0;
        color: var(--gx-muted);
        cursor: grab;
        opacity: 0.6;
        touch-action: none;
      }

      .gx-column-grip .gx-icon {
        width: 14px;
        height: 14px;
      }

      .gx-column-item:hover .gx-column-grip {
        opacity: 1;
      }

      /* the arrows are always reachable with the keyboard, shown on hover */
      .gx-column-move {
        width: 22px;
        height: 22px;
        opacity: 0;
      }

      .gx-column-item:hover .gx-column-move,
      .gx-column-item:focus-within .gx-column-move {
        opacity: 1;
      }

      .gx-column-move:disabled {
        visibility: hidden;
      }

      @media (hover: none) {
        .gx-column-move {
          opacity: 1;
        }
      }

      /* dragging a column: it follows the pointer, a line shows where it drops */
      .gx-column--dragging {
        z-index: 4;
        opacity: 0.85;
        pointer-events: none;
      }

      [data-gx-column-list="horizontal"] .gx-column--dragging {
        translate: var(--gx-drag-offset, 0px) 0;
        background: var(--gx-surface-2);
        box-shadow: var(--gx-shadow-lg);
      }

      [data-gx-column-list="vertical"] .gx-column--dragging {
        translate: 0 var(--gx-drag-offset, 0px);
        background: var(--gx-bg);
        box-shadow: var(--gx-shadow-lg);
      }

      .gx-column-marker {
        position: absolute;
        z-index: 6;
        display: none;
        background: var(--gx-accent);
        border-radius: 2px;
        box-shadow: 0 0 0 3px var(--gx-accent-soft);
        pointer-events: none;
      }

      [data-gx-column-list="horizontal"] > .gx-column-marker {
        top: 4px;
        bottom: 4px;
        width: 2px;
      }

      [data-gx-column-list="vertical"] > .gx-column-marker {
        right: 6px;
        left: 6px;
        height: 2px;
      }

      .gx-head-cell {
        cursor: grab;
      }

      .gx-root--moving-column,
      .gx-root--moving-column * {
        cursor: grabbing !important;
      }

      /* -------------------------------------------------------- filter status */
      .gx-filter-bar {
        display: flex;
        flex-wrap: wrap;
        align-items: center;
        gap: 6px;
        padding: 6px 10px;
        font-size: 12px;
        background: color-mix(in srgb, var(--gx-accent) 5%, var(--gx-surface));
        border-bottom: 1px solid var(--gx-border);
        animation: gx-fade 0.16s ease-out;
      }

      .gx-filter-count {
        display: inline-flex;
        align-items: center;
        gap: 6px;
        margin-right: 4px;
        font-weight: 600;
        font-variant-numeric: tabular-nums;
      }

      .gx-filter-count .gx-icon {
        width: 14px;
        height: 14px;
        color: var(--gx-accent);
      }

      .gx-chip--summary {
        max-width: 320px;
        height: 24px;
        background: var(--gx-bg);
        border-color: var(--gx-border);
      }

      .gx-chip-label {
        color: var(--gx-muted);
      }

      .gx-empty p {
        margin: 0 0 12px;
      }

      /* ----------------------------------------------------------------- grid */
      .gx-grid-head {
        position: sticky;
        left: 0;
        z-index: 32;
        display: flex;
        flex: none;
        width: var(--gx-grid-width);
        /* A grid narrower than its columns clips them instead of covering the
           timeline ("clip" keeps sticky positioning working) */
        overflow: clip;
        background: var(--gx-surface);
        border-right: 1px solid var(--gx-border);
      }

      .gx-head-cell {
        position: relative;
        display: flex;
        align-items: center;
        padding: 0 10px;
        font-size: 11px;
        font-weight: 600;
        letter-spacing: 0.02em;
        text-transform: uppercase;
        color: var(--gx-muted);
        border-right: 1px solid var(--gx-line);
      }

      .gx-head-cell:last-of-type {
        border-right: 0;
      }

      .gx-sort {
        display: inline-flex;
        align-items: center;
        gap: 4px;
        min-width: 0;
        max-width: 100%;
        padding: 2px 4px;
        margin: 0 -4px;
        font: inherit;
        letter-spacing: inherit;
        text-transform: inherit;
        color: inherit;
        background: transparent;
        border: 0;
        border-radius: 4px;
        cursor: pointer;
      }

      .gx-sort:hover {
        color: var(--gx-text);
      }

      .gx-sort-icon {
        width: 12px;
        height: 12px;
        color: var(--gx-accent);
      }

      .gx-col-resizer,
      .gx-splitter {
        position: absolute;
        top: 0;
        bottom: 0;
        z-index: 2;
        width: 7px;
        cursor: col-resize;
        touch-action: none;
      }

      .gx-col-resizer {
        right: -4px;
      }

      /* Inside the clipped header, its line on the border of the grid */
      .gx-splitter {
        right: 0;
        z-index: 5;
      }

      .gx-col-resizer::after,
      .gx-splitter::after {
        content: "";
        position: absolute;
        top: 20%;
        bottom: 20%;
        left: 3px;
        width: 1px;
        background: var(--gx-accent);
        opacity: 0;
        transition: opacity 0.15s;
      }

      .gx-col-resizer:hover::after,
      .gx-splitter:hover::after {
        opacity: 1;
      }

      .gx-splitter::after {
        left: auto;
        right: 0;
      }

      .gx-grid {
        position: sticky;
        left: 0;
        z-index: 20;
        flex: none;
        width: var(--gx-grid-width);
        overflow: clip;
        background: var(--gx-bg);
        border-right: 1px solid var(--gx-border);
        box-shadow: 4px 0 12px -10px rgba(15, 23, 42, 0.25);
      }

      .gx-row {
        position: relative;
        display: flex;
        align-items: center;
        height: var(--gx-row-height);
        border-bottom: 1px solid var(--gx-line);
        cursor: default;
        transition: background-color 0.12s;
      }

      .gx-row:hover {
        background: var(--gx-row-hover);
      }

      .gx-row--selected,
      .gx-row--selected:hover {
        background: var(--gx-row-selected);
      }

      .gx-row--selected::before {
        content: "";
        position: absolute;
        top: 0;
        bottom: 0;
        left: 0;
        width: 3px;
        background: var(--gx-accent);
        border-radius: 0 3px 3px 0;
      }

      .gx-row--project {
        font-weight: 600;
      }

      .gx-row--group {
        font-weight: 650;
        background: var(--gx-surface);
      }

      .gx-count {
        flex: none;
        min-width: 20px;
        padding: 0 6px;
        margin-left: 6px;
        font-size: 11px;
        font-weight: 600;
        line-height: 18px;
        text-align: center;
        color: var(--gx-muted);
        background: var(--gx-surface-2);
        border-radius: 999px;
      }

      .gx-row--dragging {
        opacity: 0.45;
      }

      .gx-row--drop-inside {
        background: var(--gx-accent-soft);
        box-shadow: inset 0 0 0 1px var(--gx-accent);
      }

      .gx-cell {
        display: flex;
        align-items: center;
        height: 100%;
        min-width: 0;
        padding: 0 10px;
        overflow: hidden;
      }

      .gx-align-center {
        justify-content: center;
        text-align: center;
      }

      .gx-align-right {
        justify-content: flex-end;
        text-align: right;
      }

      .gx-cell--tree {
        gap: 4px;
        padding-left: 8px;
      }

      .gx-indent {
        flex: none;
      }

      .gx-toggle,
      .gx-toggle-spacer {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        flex: none;
        width: 20px;
        height: 20px;
      }

      .gx-toggle {
        padding: 0;
        color: var(--gx-muted);
        background: transparent;
        border: 0;
        border-radius: 5px;
        cursor: pointer;
        transition: background-color 0.15s, color 0.15s;
      }

      .gx-toggle:hover {
        color: var(--gx-text);
        background: var(--gx-surface-2);
      }

      .gx-toggle .gx-icon {
        width: 14px;
        height: 14px;
        transition: transform 0.18s var(--gx-ease);
      }

      .gx-toggle--loading .gx-icon {
        display: none;
      }

      .gx-toggle--loading::after {
        content: "";
        width: 11px;
        height: 11px;
        border: 2px solid var(--gx-border);
        border-top-color: var(--gx-accent);
        border-radius: 50%;
        animation: gx-spin 0.7s linear infinite;
      }

      @keyframes gx-spin {
        to { transform: rotate(360deg); }
      }

      .gx-toggle--open .gx-icon {
        transform: rotate(90deg);
      }

      .gx-type-dot {
        flex: none;
        width: 8px;
        height: 8px;
        margin: 0 4px 0 2px;
        background: var(--gx-task);
        border-radius: 50%;
      }

      .gx-type-dot--project {
        background: var(--gx-project);
        border-radius: 2px;
      }

      .gx-type-dot--milestone {
        background: var(--gx-milestone);
        border-radius: 1px;
        transform: rotate(45deg) scale(0.9);
      }

      .gx-add {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 24px;
        height: 24px;
        padding: 0;
        color: var(--gx-muted);
        background: transparent;
        border: 1px solid transparent;
        border-radius: 6px;
        cursor: pointer;
        opacity: 0.55;
        transition: opacity 0.15s, background-color 0.15s, color 0.15s, border-color 0.15s;
      }

      .gx-row:hover .gx-add,
      .gx-head-cell .gx-add,
      .gx-add:focus-visible {
        opacity: 1;
      }

      .gx-add:hover {
        color: var(--gx-accent);
        background: var(--gx-accent-soft);
        border-color: var(--gx-accent-soft);
      }

      /* Row actions: shown on hover, focus and selection (always on touch screens) */
      .gx-actions {
        display: flex;
        align-items: center;
        gap: 2px;
      }

      .gx-action {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        flex: none;
        width: 24px;
        height: 24px;
        padding: 0;
        color: var(--gx-muted);
        background: transparent;
        border: 0;
        border-radius: 6px;
        cursor: pointer;
        opacity: 0;
        transition: opacity 0.15s, background-color 0.15s, color 0.15s, transform 0.1s;
      }

      .gx-action .gx-icon {
        width: 15px;
        height: 15px;
      }

      .gx-row:hover .gx-action,
      .gx-row:focus-within .gx-action,
      .gx-row--selected .gx-action {
        opacity: 1;
      }

      @media (hover: none) {
        .gx-action {
          opacity: 1;
        }
      }

      .gx-action:hover {
        color: var(--gx-text);
        background: var(--gx-surface-2);
      }

      .gx-action:active {
        transform: scale(0.92);
      }

      .gx-action:focus-visible {
        opacity: 1;
        outline: 2px solid var(--gx-accent);
        outline-offset: -1px;
      }

      .gx-action--drag {
        cursor: grab;
        touch-action: none;
      }

      .gx-action--drag:active {
        cursor: grabbing;
        transform: none;
      }

      .gx-action--drag[aria-disabled="true"] {
        cursor: not-allowed;
      }

      .gx-row:hover .gx-action--drag[aria-disabled="true"],
      .gx-row--selected .gx-action--drag[aria-disabled="true"] {
        opacity: 0.35;
      }

      .gx-action--drag[aria-disabled="true"]:hover {
        background: transparent;
      }

      .gx-action--block.gx-action--on {
        color: var(--gx-danger);
      }

      .gx-action--block:hover,
      .gx-action--delete:hover {
        color: var(--gx-danger);
        background: var(--gx-danger-soft);
      }

      .gx-action--restriction:hover {
        color: var(--gx-warning-strong);
        background: var(--gx-warning-soft);
      }

      .gx-action--rename:hover,
      .gx-action--edit:hover,
      .gx-action--detail:hover {
        color: var(--gx-accent-strong);
        background: var(--gx-accent-soft);
      }

      .gx-cell-editor {
        width: 100%;
        margin: 0 -6px;
      }

      .gx-spacer {
        pointer-events: none;
      }

      .gx-wbs {
        font-variant-numeric: tabular-nums;
        color: var(--gx-muted);
      }

      /* Blocked tasks and open restrictions, next to the task name */
      .gx-flag {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 2px;
        flex: none;
        height: 18px;
        min-width: 18px;
        font-size: 11px;
        font-weight: 650;
        line-height: 1;
        font-variant-numeric: tabular-nums;
        border-radius: 999px;
      }

      .gx-flag .gx-icon {
        width: 12px;
        height: 12px;
      }

      .gx-flag--blocked {
        color: var(--gx-danger-strong);
        background: var(--gx-danger-soft);
      }

      .gx-flag--restricted {
        padding: 0 6px 0 4px;
        color: var(--gx-warning-strong);
        background: var(--gx-warning-soft);
      }

      .gx-row--restricted {
        box-shadow: inset 2px 0 0 var(--gx-warning);
      }

      .gx-row--blocked {
        box-shadow: inset 2px 0 0 var(--gx-danger);
      }

      .gx-empty {
        padding: 32px 16px;
        color: var(--gx-muted);
        text-align: center;
      }

      .gx-drop-marker {
        position: absolute;
        left: 8px;
        right: 8px;
        z-index: 3;
        display: none;
        height: 2px;
        background: var(--gx-accent);
        border-radius: 2px;
        pointer-events: none;
        box-shadow: 0 0 0 3px var(--gx-accent-soft);
      }

      /* ---------------------------------------------------------------- scale */
      .gx-scale {
        position: relative;
        flex: none;
      }

      .gx-scale-row {
        position: relative;
        height: var(--gx-scale-row-height);
        border-bottom: 1px solid var(--gx-line);
      }

      .gx-scale-row:last-child {
        border-bottom: 0;
      }

      .gx-scale-row:first-child:not(:last-child) .gx-scale-cell {
        justify-content: flex-start;
        padding-left: 10px;
        font-weight: 600;
        color: var(--gx-text);
      }

      .gx-scale-cell {
        position: absolute;
        top: 0;
        bottom: 0;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 0 4px;
        font-size: 12px;
        color: var(--gx-muted);
        border-right: 1px solid var(--gx-line);
      }

      .gx-scale-cell--weekend {
        background: var(--gx-weekend);
      }

      .gx-scale-cell--today {
        font-weight: 700;
        color: var(--gx-accent);
      }

      .gx-scale-cell--today::after {
        content: "";
        position: absolute;
        right: 25%;
        bottom: 3px;
        left: 25%;
        height: 2px;
        background: var(--gx-accent);
        border-radius: 2px;
      }

      /* ---------------------------------------------------------------- chart */
      .gx-chart {
        position: relative;
        flex: none;
        background-image:
          linear-gradient(to right, transparent calc(var(--gx-column-width) - 1px), var(--gx-line) 0),
          linear-gradient(to bottom, transparent calc(var(--gx-row-height) - 1px), var(--gx-line) 0);
        background-size: var(--gx-column-width) 100%, 100% var(--gx-row-height);
      }

      .gx-highlights,
      .gx-links,
      .gx-draft {
        position: absolute;
        inset: 0;
        pointer-events: none;
      }

      .gx-highlight {
        position: absolute;
        top: 0;
        bottom: 0;
        background: var(--gx-weekend);
      }

      .gx-links {
        z-index: 1;
        overflow: visible;
      }

      .gx-link {
        color: var(--gx-link-color, var(--gx-link));
        cursor: pointer;
      }

      .gx-link-hit {
        fill: none;
        stroke: transparent;
        stroke-width: 12;
        pointer-events: stroke;
      }

      .gx-link-line {
        fill: none;
        stroke: currentColor;
        stroke-width: 1.5;
        stroke-linejoin: round;
        transition: stroke-width 0.15s;
      }

      .gx-link-arrow {
        fill: currentColor;
      }

      .gx-link:hover,
      .gx-link--selected {
        color: var(--gx-accent);
      }

      .gx-link:hover .gx-link-line,
      .gx-link--selected .gx-link-line {
        stroke-width: 2.25;
      }

      .gx-draft {
        z-index: 8;
        width: 100%;
        height: 100%;
        overflow: visible;
      }

      .gx-draft-line {
        stroke: var(--gx-accent);
        stroke-width: 2;
        stroke-dasharray: 5 4;
        stroke-linecap: round;
      }

      .gx-draft-rect {
        fill: var(--gx-accent-soft);
        stroke: var(--gx-accent);
        stroke-width: 1.5;
        stroke-dasharray: 4 3;
      }

      .gx-marker {
        position: absolute;
        top: 0;
        bottom: 0;
        z-index: 4;
        width: 0;
        border-left: 2px dashed var(--gx-marker-color, #f43f5e);
        pointer-events: none;
      }

      .gx-marker--today {
        --gx-marker-color: var(--gx-accent);
        border-left-style: solid;
      }

      .gx-marker-label {
        position: sticky;
        top: calc(var(--gx-header-height, 64px) + 6px);
        display: inline-block;
        margin-left: 4px;
        padding: 1px 7px;
        font-size: 11px;
        font-weight: 600;
        color: #ffffff;
        white-space: nowrap;
        background: var(--gx-marker-color, #f43f5e);
        border-radius: 999px;
        box-shadow: var(--gx-shadow);
      }

      /* ----------------------------------------------------------------- bars */
      .gx-bar {
        position: absolute;
        top: var(--gx-y);
        left: calc(var(--gx-x) + var(--gx-dx, 0px));
        z-index: 2;
        width: calc(var(--gx-w) + var(--gx-dw, 0px));
        height: var(--gx-bar-height);
        color: var(--gx-bar-text, var(--gx-task-text));
        border-radius: var(--gx-radius);
        outline: none;
        cursor: grab;
        touch-action: none;
        user-select: none;
        -webkit-user-select: none;
      }

      .gx-bar-body {
        position: absolute;
        inset: 0;
        display: flex;
        align-items: center;
        overflow: hidden;
        background: var(--gx-bar-bg, var(--gx-task));
        border-radius: inherit;
        box-shadow: var(--gx-shadow), inset 0 1px 0 rgba(255, 255, 255, 0.12);
        transition: box-shadow 0.18s var(--gx-ease), filter 0.18s;
      }

      /* each bar is a stacking context: lift the hovered one so its tooltip
         is painted above the bars of the following rows */
      .gx-bar:hover {
        z-index: 6;
      }

      .gx-bar:hover .gx-bar-body {
        filter: brightness(1.05) saturate(1.05);
        box-shadow: 0 6px 16px -6px rgba(15, 23, 42, 0.45), inset 0 1px 0 rgba(255, 255, 255, 0.12);
      }

      .gx-bar-progress {
        position: absolute;
        inset: 0 auto 0 0;
        width: var(--gx-pd, var(--gx-p));
        background: var(--gx-bar-progress, var(--gx-task-progress));
        transition: width 0.2s var(--gx-ease);
      }

      .gx-bar--dragging .gx-bar-progress {
        transition: none;
      }

      .gx-bar-text {
        position: relative;
        min-width: 0;
        padding: 0 10px;
        overflow: hidden;
        font-size: 12px;
        font-weight: 500;
        white-space: nowrap;
        text-overflow: ellipsis;
        text-shadow: 0 1px 1px rgba(15, 23, 42, 0.18);
      }

      .gx-bar--project .gx-bar-body {
        background: var(--gx-bar-bg, var(--gx-project));
      }

      .gx-bar--project .gx-bar-progress {
        background: var(--gx-bar-progress, var(--gx-project-progress));
      }

      .gx-bar--project .gx-bar-text {
        font-weight: 650;
      }

      .gx-bar--milestone .gx-bar-body {
        overflow: visible;
        background: transparent;
        box-shadow: none;
      }

      .gx-bar--milestone .gx-bar-body::before {
        content: "";
        position: absolute;
        top: 50%;
        left: 50%;
        width: 72%;
        height: 72%;
        background: var(--gx-bar-bg, var(--gx-milestone));
        border: 1px solid var(--gx-milestone-border);
        border-radius: 3px;
        box-shadow: var(--gx-shadow);
        transform: translate(-50%, -50%) rotate(45deg);
      }

      .gx-bar--milestone .gx-bar-text {
        position: absolute;
        left: 100%;
        padding-left: 6px;
        color: var(--gx-text);
        text-shadow: none;
        overflow: visible;
      }

      .gx-bar--locked {
        cursor: pointer;
      }

      .gx-bar--selected .gx-bar-body {
        box-shadow: 0 0 0 2px var(--gx-bg), 0 0 0 4px var(--gx-accent), 0 8px 18px -8px rgba(15, 23, 42, 0.5);
      }

      .gx-bar--milestone.gx-bar--selected .gx-bar-body {
        box-shadow: none;
      }

      .gx-bar--milestone.gx-bar--selected .gx-bar-body::before {
        box-shadow: 0 0 0 2px var(--gx-bg), 0 0 0 4px var(--gx-accent);
      }

      .gx-bar--dragging {
        z-index: 7;
        cursor: grabbing;
      }

      .gx-bar--dragging .gx-bar-body {
        opacity: 0.92;
        box-shadow: var(--gx-shadow-lg);
        transition: none;
      }

      .gx-bar--link-target .gx-bar-body {
        box-shadow: 0 0 0 2px var(--gx-bg), 0 0 0 4px var(--gx-accent);
      }

      .gx-handle {
        position: absolute;
        top: 0;
        bottom: 0;
        z-index: 2;
        width: 10px;
        cursor: ew-resize;
      }

      .gx-handle--start {
        left: -3px;
      }

      .gx-handle--end {
        right: -3px;
      }

      .gx-handle::after {
        content: "";
        position: absolute;
        top: 25%;
        bottom: 25%;
        left: 4px;
        width: 2px;
        background: rgba(255, 255, 255, 0.85);
        border-radius: 2px;
        opacity: 0;
        transition: opacity 0.15s;
      }

      .gx-bar:hover .gx-handle::after {
        opacity: 1;
      }

      .gx-progress-handle {
        position: absolute;
        bottom: -7px;
        left: var(--gx-pd, var(--gx-p));
        z-index: 3;
        width: 12px;
        height: 8px;
        background: var(--gx-bg);
        border: 2px solid var(--gx-accent);
        border-radius: 3px 3px 6px 6px;
        transform: translateX(-50%);
        cursor: ew-resize;
        opacity: 0;
        transition: opacity 0.15s;
      }

      .gx-bar:hover .gx-progress-handle,
      .gx-bar--dragging .gx-progress-handle {
        opacity: 1;
      }

      .gx-btn--active {
        color: var(--gx-accent-strong);
        background: var(--gx-accent-soft);
      }

      .gx-bar--critical .gx-bar-body {
        background: var(--gx-bar-bg, var(--gx-critical, #e11d48));
      }

      .gx-bar--critical .gx-bar-progress {
        background: var(--gx-bar-progress, var(--gx-critical-progress, #9f1239));
      }

      .gx-bar--milestone.gx-bar--critical .gx-bar-body::before {
        background: var(--gx-critical, #e11d48);
        border-color: var(--gx-critical-progress, #9f1239);
      }

      .gx-link--critical {
        color: var(--gx-critical, #e11d48);
      }

      .gx-link--critical .gx-link-line {
        stroke-width: 2;
      }

      .gx-critical-text {
        font-weight: 600;
        color: var(--gx-critical, #e11d48);
      }

      .gx-slack {
        position: absolute;
        top: 50%;
        left: 100%;
        height: 4px;
        margin-top: -2px;
        background: repeating-linear-gradient(90deg, var(--gx-muted) 0 4px, transparent 4px 7px);
        border-radius: 2px;
        opacity: 0.55;
        pointer-events: none;
      }

      .gx-bar--segment .gx-bar-body {
        box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.35), var(--gx-shadow);
      }

      .gx-rollups {
        position: absolute;
        inset: 0;
        z-index: 3;
        pointer-events: none;
      }

      .gx-rollup {
        position: absolute;
        height: 6px;
        margin-top: -3px;
        background: var(--gx-bg);
        border: 2px solid var(--gx-rollup, #f59e0b);
        border-radius: 3px;
      }

      .gx-rollup--milestone {
        width: 10px !important;
        height: 10px;
        margin: -5px 0 0 -5px;
        background: var(--gx-rollup, #f59e0b);
        border: 0;
        border-radius: 2px;
        transform: rotate(45deg);
      }

      .gx-resources {
        border-top: 2px solid var(--gx-border);
      }

      .gx-resources-row {
        display: flex;
        height: var(--gx-row-height);
        border-bottom: 1px solid var(--gx-line);
      }

      .gx-resources-row--head {
        height: 28px;
        font-size: 11px;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.02em;
        color: var(--gx-muted);
        background: var(--gx-surface);
      }

      .gx-resources-name {
        position: sticky;
        left: 0;
        z-index: 2;
        display: flex;
        flex: none;
        align-items: center;
        justify-content: space-between;
        gap: 8px;
        width: var(--gx-grid-width);
        padding: 0 12px;
        background: inherit;
        background-color: var(--gx-bg);
        border-right: 1px solid var(--gx-border);
      }

      .gx-resources-row--head .gx-resources-name {
        background-color: var(--gx-surface);
      }

      .gx-resources-capacity {
        font-size: 11px;
        color: var(--gx-muted);
        font-variant-numeric: tabular-nums;
      }

      .gx-resources-row--overloaded .gx-resources-name {
        color: var(--gx-danger);
        font-weight: 600;
      }

      .gx-resources-cells {
        position: relative;
        flex: none;
      }

      .gx-load {
        position: absolute;
        top: 4px;
        bottom: 4px;
        display: flex;
        align-items: flex-end;
        justify-content: center;
        overflow: hidden;
        font-size: 11px;
        font-weight: 600;
        color: var(--gx-text);
        background: linear-gradient(to top, var(--gx-accent-soft) var(--gx-load), transparent 0);
        border-radius: 4px;
      }

      .gx-load--over {
        color: var(--gx-danger);
        background: linear-gradient(to top, var(--gx-danger-soft) var(--gx-load), transparent 0);
        box-shadow: inset 0 -2px 0 var(--gx-danger);
      }

      .gx-checks {
        display: flex;
        flex-wrap: wrap;
        gap: 6px 14px;
      }

      .gx-check {
        display: inline-flex;
        align-items: center;
        gap: 6px;
        cursor: pointer;
      }

      .gx-check input {
        accent-color: var(--gx-accent);
      }

      .gx-row-marks {
        position: absolute;
        inset: 0;
        z-index: 1;
        pointer-events: none;
      }

      .gx-baseline {
        position: absolute;
        height: 5px;
        background: var(--gx-baseline, #94a3b8);
        border-radius: 3px;
        opacity: 0.85;
      }

      .gx-deadline {
        position: absolute;
        z-index: 3;
        width: 0;
        border-left: 2px solid var(--gx-deadline, #f59e0b);
      }

      .gx-deadline::before {
        content: "";
        position: absolute;
        top: -4px;
        left: 0;
        width: 9px;
        height: 7px;
        background: var(--gx-deadline, #f59e0b);
        clip-path: polygon(0 0, 100% 50%, 0 100%);
      }

      .gx-deadline--overdue {
        --gx-deadline: var(--gx-danger);
      }

      .gx-deadline-gap {
        position: absolute;
        height: 0;
        margin-top: -1px;
        border-top: 2px dotted var(--gx-deadline, #f59e0b);
        opacity: 0.7;
      }

      .gx-deadline-gap--overdue {
        --gx-deadline: var(--gx-danger);
        border-top-style: dashed;
        opacity: 0.85;
      }

      /* the gap is computed from the dates on the server: hide it while dragging */
      .gx-root--dragging .gx-deadline-gap {
        opacity: 0;
      }

      .gx-baseline--milestone {
        width: 8px;
        height: 8px;
        margin-left: -4px;
        background: transparent;
        border: 2px solid var(--gx-baseline, #94a3b8);
        border-radius: 1px;
        transform: rotate(45deg);
      }

      /* Blocked: hatched in the danger tone. Open restrictions: a dot on the corner */
      .gx-bar--blocked .gx-bar-body::after {
        content: "";
        position: absolute;
        inset: 0;
        border-radius: inherit;
        background: repeating-linear-gradient(
          -45deg,
          transparent 0 5px,
          color-mix(in srgb, var(--gx-danger) 45%, transparent) 5px 7.5px
        );
        box-shadow: inset 0 0 0 1.5px var(--gx-danger);
        pointer-events: none;
      }

      .gx-bar--blocked .gx-bar-text {
        z-index: 1;
      }

      .gx-bar--milestone.gx-bar--blocked .gx-bar-body::after {
        display: none;
      }

      .gx-bar--milestone.gx-bar--blocked .gx-bar-body::before {
        border: 2px solid var(--gx-danger);
      }

      .gx-bar--restricted::before {
        content: "";
        position: absolute;
        top: -3px;
        left: -3px;
        z-index: 4;
        width: 9px;
        height: 9px;
        background: var(--gx-warning);
        border-radius: 50%;
        box-shadow: 0 0 0 2px var(--gx-bg);
        pointer-events: none;
      }

      .gx-bar--milestone.gx-bar--restricted::before {
        top: -4px;
        left: calc(50% - 4.5px);
      }

      .gx-bar--overdue .gx-bar-body {
        box-shadow: inset 0 0 0 2px var(--gx-danger), var(--gx-shadow);
      }

      .gx-constraint {
        position: absolute;
        top: -5px;
        bottom: -5px;
        z-index: 1;
        width: 0;
        border-left: 2px solid var(--gx-danger);
        pointer-events: auto;
      }

      .gx-constraint::before {
        content: "";
        position: absolute;
        top: -2px;
        left: -5px;
        border: 4px solid transparent;
        border-top-color: var(--gx-danger);
      }

      .gx-link-point {
        position: absolute;
        top: 50%;
        z-index: 3;
        width: 12px;
        height: 12px;
        margin-top: -6px;
        background: var(--gx-bg);
        border: 2px solid var(--gx-accent);
        border-radius: 50%;
        cursor: crosshair;
        opacity: 0;
        transform: scale(0.6);
        transition: opacity 0.15s, transform 0.15s var(--gx-ease);
      }

      .gx-link-point--start {
        left: -18px;
      }

      .gx-link-point--end {
        right: -18px;
      }

      .gx-bar:hover .gx-link-point,
      .gx-root--linking .gx-link-point {
        opacity: 1;
        transform: scale(1);
      }

      .gx-link-point:hover {
        background: var(--gx-accent);
        transform: scale(1.2);
      }

      .gx-root--dragging:not(.gx-root--linking) .gx-link-point {
        opacity: 0;
      }

      /* -------------------------------------------------------------- tooltip */
      /* hidden tooltips use display: none so they never extend the scroll area */
      .gx-tooltip {
        position: absolute;
        top: calc(100% + 10px);
        left: 0;
        z-index: 40;
        display: none;
        min-width: 190px;
        max-width: 280px;
        padding: 10px 12px;
        color: var(--gx-tooltip-text);
        background: var(--gx-tooltip-bg);
        border-radius: 10px;
        box-shadow: var(--gx-shadow-lg);
        cursor: default;
        pointer-events: none;
      }

      .gx-bar:hover .gx-tooltip {
        display: block;
        animation: gx-tip 0.15s var(--gx-ease) 0.45s both;
      }

      .gx-root--dragging .gx-tooltip,
      .gx-bar--selected .gx-tooltip {
        display: none;
      }

      .gx-summary-title {
        margin: 0 0 6px;
        font-weight: 600;
        overflow-wrap: anywhere;
      }

      .gx-summary {
        display: grid;
        grid-template-columns: auto 1fr;
        gap: 3px 12px;
        margin: 0;
        font-size: 12px;
      }

      .gx-summary dt {
        opacity: 0.65;
      }

      .gx-summary dd {
        margin: 0;
        font-variant-numeric: tabular-nums;
      }

      .gx-summary-tags {
        display: flex;
        flex-wrap: wrap;
        gap: 4px;
        margin: 8px 0 0;
      }

      .gx-tag {
        display: inline-flex;
        align-items: center;
        gap: 4px;
        padding: 2px 8px 2px 6px;
        font-size: 11px;
        font-weight: 600;
        border-radius: 999px;
      }

      .gx-tag .gx-icon {
        width: 12px;
        height: 12px;
      }

      .gx-tag--blocked {
        color: var(--gx-danger-strong);
        background: var(--gx-danger-soft);
      }

      .gx-tag--restricted {
        color: var(--gx-warning-strong);
        background: var(--gx-warning-soft);
      }

      /* tooltips are dark in both themes */
      .gx-tooltip .gx-tag--blocked {
        color: #fda4af;
        background: rgba(244, 63, 94, 0.2);
      }

      .gx-tooltip .gx-tag--restricted {
        color: #fcd34d;
        background: rgba(251, 191, 36, 0.16);
      }

      /* --------------------------------------------------------------- popups */
      .gx-popup {
        position: absolute;
        z-index: 45;
        min-width: 240px;
        max-width: 320px;
        padding: 14px 14px 12px;
        color: var(--gx-text);
        background: var(--gx-bg);
        border: 1px solid var(--gx-border);
        border-radius: 12px;
        box-shadow: var(--gx-shadow-lg);
        animation: gx-pop 0.16s var(--gx-ease);
      }

      /* Moved by the hook into the visible part of the timeline */
      .gx-quick-info {
        translate: var(--gx-quick-info-dx, 0px) 0;
      }

      .gx-popup .gx-summary dt {
        color: var(--gx-muted);
        opacity: 1;
      }

      .gx-popup-close {
        position: absolute;
        top: 6px;
        right: 6px;
        width: 26px;
        height: 26px;
      }

      .gx-popup .gx-summary-title {
        padding-right: 24px;
      }

      .gx-popup-actions {
        display: flex;
        gap: 6px;
        padding-top: 10px;
        margin-top: 10px;
        border-top: 1px solid var(--gx-line);
      }

      .gx-notice {
        position: absolute;
        bottom: 16px;
        left: 50%;
        z-index: 80;
        display: flex;
        align-items: center;
        gap: 6px;
        padding: 6px 6px 6px 14px;
        color: var(--gx-tooltip-text);
        background: var(--gx-tooltip-bg);
        border-radius: 999px;
        box-shadow: var(--gx-shadow-lg);
        transform: translateX(-50%);
        animation: gx-rise 0.2s var(--gx-ease);
      }

      .gx-notice .gx-btn--icon {
        width: 26px;
        height: 26px;
        color: inherit;
      }

      .gx-notice .gx-btn--icon:hover {
        background: rgba(255, 255, 255, 0.1);
      }

      /* -------------------------------------------------------------- dialogs */
      .gx-backdrop {
        position: fixed;
        inset: 0;
        z-index: 1000;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 16px;
        background: var(--gx-backdrop);
        backdrop-filter: blur(3px);
        -webkit-backdrop-filter: blur(3px);
        animation: gx-fade 0.16s ease-out;
      }

      .gx-backdrop--top {
        z-index: 1010;
      }

      .gx-dialog {
        display: flex;
        flex-direction: column;
        width: min(520px, 100%);
        max-height: calc(100vh - 32px);
        overflow: auto;
        color: var(--gx-text);
        background: var(--gx-bg);
        border: 1px solid var(--gx-border);
        border-radius: 16px;
        box-shadow: var(--gx-shadow-lg);
        animation: gx-rise 0.2s var(--gx-ease);
      }

      .gx-dialog--small {
        width: min(420px, 100%);
      }

      .gx-dialog-header {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 12px;
        padding: 16px 18px 4px;
      }

      .gx-dialog-header h2 {
        margin: 0;
        font-size: 16px;
        font-weight: 650;
        letter-spacing: -0.01em;
      }

      .gx-dialog-body {
        display: flex;
        flex-direction: column;
        gap: 14px;
        padding: 14px 18px 18px;
      }

      .gx-dialog-footer {
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 12px 18px;
        background: var(--gx-surface);
        border-top: 1px solid var(--gx-border);
        border-radius: 0 0 16px 16px;
      }

      .gx-field {
        display: flex;
        flex: 1;
        flex-direction: column;
        gap: 6px;
        min-width: 0;
      }

      .gx-field label,
      .gx-fieldset legend {
        font-size: 12px;
        font-weight: 600;
        color: var(--gx-muted);
      }

      .gx-field-row {
        display: flex;
        flex-wrap: wrap;
        gap: 12px;
      }

      .gx-field-row > .gx-field {
        flex: 1 1 160px;
      }

      .gx-fieldset {
        padding: 0;
        margin: 0;
        border: 0;
      }

      .gx-fieldset legend {
        padding: 0;
        margin-bottom: 8px;
      }

      .gx-input {
        width: 100%;
        height: 36px;
        padding: 0 10px;
        font: inherit;
        color: var(--gx-text);
        background: var(--gx-bg);
        border: 1px solid var(--gx-border);
        border-radius: 8px;
        outline: none;
        transition: border-color 0.15s, box-shadow 0.15s;
        color-scheme: light dark;
      }

      .gx-input:hover {
        border-color: color-mix(in srgb, var(--gx-border) 50%, var(--gx-muted));
      }

      .gx-input:focus {
        border-color: var(--gx-accent);
        box-shadow: 0 0 0 3px var(--gx-accent-soft);
      }

      .gx-input--invalid,
      .gx-input--invalid:focus {
        border-color: var(--gx-danger);
        box-shadow: 0 0 0 3px var(--gx-danger-soft);
      }

      .gx-input--cell {
        height: calc(var(--gx-row-height) - 8px);
        padding: 0 6px;
        border-radius: 6px;
      }

      .gx-field--range .gx-input {
        height: 22px;
        padding: 0;
        accent-color: var(--gx-accent);
        border: 0;
        box-shadow: none;
      }

      .gx-error {
        margin: 0;
        font-size: 12px;
        color: var(--gx-danger);
      }

      .gx-link-route {
        display: flex;
        align-items: center;
        gap: 8px;
        margin: 0;
        padding: 10px 12px;
        font-weight: 500;
        background: var(--gx-surface-2);
        border-radius: 8px;
      }

      .gx-confirm {
        flex-direction: row;
        gap: 14px;
        padding-top: 20px;
      }

      .gx-confirm-icon {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        flex: none;
        width: 40px;
        height: 40px;
        color: var(--gx-danger);
        background: var(--gx-danger-soft);
        border-radius: 50%;
      }

      .gx-confirm-icon .gx-icon {
        width: 22px;
        height: 22px;
      }

      .gx-confirm-message {
        margin: 2px 0 4px;
        font-weight: 600;
      }

      .gx-confirm-detail {
        margin: 0;
        color: var(--gx-muted);
      }

      /* -------------------------------------------------------------- plans */
      .gx-scale-band {
        position: absolute;
        top: 0;
        bottom: 0;
        z-index: 1;
        background: var(--gx-plan-soft);
        border: 1.5px solid var(--gx-plan);
        border-bottom: 0;
        border-radius: 6px 6px 0 0;
        pointer-events: none;
      }

      .gx-plan-band {
        position: absolute;
        top: 0;
        bottom: 0;
        background: var(--gx-plan-soft);
        border-inline: 1.5px solid var(--gx-plan);
        pointer-events: none;
      }

      .gx-plan-band-label {
        position: sticky;
        top: calc(var(--gx-header-height, 64px) + 6px);
        z-index: 4;
        display: block;
        width: max-content;
        max-width: calc(100% - 8px);
        margin: 0 4px 0 auto;
        padding: 1px 7px;
        overflow: hidden;
        font-size: 11px;
        font-weight: 600;
        color: #ffffff;
        white-space: nowrap;
        text-overflow: ellipsis;
        background: var(--gx-plan);
        border-radius: 999px;
        box-shadow: var(--gx-shadow);
      }

      .gx-root--plans .gx-bar--committed,
      .gx-root--plans .gx-bar--not-committed {
        --gx-bar-text: var(--gx-plan-text);
      }

      .gx-root--plans .gx-bar--committed {
        --gx-plan-bg: var(--gx-committed);
        --gx-plan-progress: var(--gx-committed-progress);
        --gx-plan-border: var(--gx-committed-border);
        --gx-plan-text: var(--gx-committed-text);
      }

      .gx-root--plans .gx-bar--not-committed {
        --gx-plan-bg: var(--gx-not-committed);
        --gx-plan-progress: var(--gx-not-committed-progress);
        --gx-plan-border: var(--gx-not-committed-border);
        --gx-plan-text: var(--gx-not-committed-text);
      }

      .gx-root--plans :is(.gx-bar--committed, .gx-bar--not-committed):not(.gx-bar--milestone)
        .gx-bar-body {
        background: var(--gx-plan-bg);
        box-shadow: inset 0 0 0 1px var(--gx-plan-border), var(--gx-shadow);
      }

      .gx-root--plans :is(.gx-bar--committed, .gx-bar--not-committed) .gx-bar-progress {
        background: var(--gx-plan-progress);
      }

      .gx-root--plans :is(.gx-bar--committed, .gx-bar--not-committed) .gx-bar-text {
        text-shadow: none;
      }

      /* the critical path stays visible as a red underline */
      .gx-root--plans
        :is(.gx-bar--committed, .gx-bar--not-committed).gx-bar--critical:not(.gx-bar--milestone)
        .gx-bar-body {
        box-shadow: inset 0 -3px 0 var(--gx-critical, #e11d48), inset 0 0 0 1px var(--gx-plan-border),
          var(--gx-shadow);
      }

      .gx-root--plans .gx-bar--selected:is(.gx-bar--committed, .gx-bar--not-committed)
        .gx-bar-body {
        box-shadow: 0 0 0 2px var(--gx-bg), 0 0 0 4px var(--gx-accent), 0 8px 18px -8px rgba(15, 23, 42, 0.5);
      }

      .gx-root--plans .gx-bar--milestone.gx-bar--committed .gx-bar-body::before {
        background: var(--gx-committed-progress);
        border-color: var(--gx-committed-border);
      }

      /* the lookahead shows its weeks only: bars that go on are cut at the edges */
      .gx-root--windowed .gx-chart {
        overflow-x: clip;
      }

      .gx-lookahead .gx-menu-list {
        right: auto;
        left: 0;
      }

      .gx-menu-item--checked {
        font-weight: 600;
        color: var(--gx-accent-strong);
      }

      .gx-menu-check {
        color: var(--gx-accent);
      }

      .gx-invisible {
        visibility: hidden;
      }

      /* ------------------------------------------------------ summary bars */
      .gx-summary-cap {
        display: none;
      }

      .gx-root--bracket .gx-bar--summary .gx-bar-body {
        inset: 16% 0 auto 0;
        height: 40%;
        overflow: visible;
        border-radius: 2px 2px 0 0;
      }

      .gx-root--bracket .gx-bar--summary .gx-bar-progress {
        border-radius: inherit;
      }

      .gx-root--bracket .gx-bar--summary .gx-summary-cap {
        position: absolute;
        top: 100%;
        display: block;
        width: 0;
        height: 0;
        border-top: calc(var(--gx-bar-height) * 0.32) solid var(--gx-bar-bg, var(--gx-project));
      }

      .gx-root--bracket .gx-bar--summary .gx-summary-cap--start {
        left: 0;
        border-right: calc(var(--gx-bar-height) * 0.3) solid transparent;
      }

      .gx-root--bracket .gx-bar--summary .gx-summary-cap--end {
        right: 0;
        border-left: calc(var(--gx-bar-height) * 0.3) solid transparent;
      }

      .gx-root--bracket .gx-bar--summary.gx-bar--critical .gx-summary-cap {
        border-top-color: var(--gx-bar-bg, var(--gx-critical, #e11d48));
      }

      .gx-root--bracket .gx-bar--summary .gx-bar-text {
        position: absolute;
        left: 100%;
        padding-left: calc(var(--gx-bar-height) * 0.3 + 6px);
        overflow: visible;
        color: var(--gx-text);
        text-shadow: none;
      }

      .gx-root--bracket .gx-bar--summary:hover .gx-bar-body {
        box-shadow: var(--gx-shadow);
      }

      /* -------------------------------------------------------------- legend */
      .gx-legend {
        display: flex;
        flex-wrap: wrap;
        align-items: center;
        gap: 8px 16px;
        padding: 9px 14px;
        font-size: 12px;
        color: var(--gx-muted);
        background: var(--gx-surface);
        border-top: 1px solid var(--gx-border);
      }

      .gx-legend-title {
        font-size: 11px;
        font-weight: 650;
        color: var(--gx-text);
        letter-spacing: 0.04em;
        text-transform: uppercase;
      }

      .gx-legend-list {
        display: flex;
        flex-wrap: wrap;
        gap: 6px 14px;
        margin: 0;
        padding: 0;
        list-style: none;
      }

      .gx-legend-item {
        display: inline-flex;
        align-items: center;
        gap: 6px;
        white-space: nowrap;
      }

      .gx-legend-group {
        padding-left: 14px;
        font-weight: 600;
        color: var(--gx-text);
        border-left: 1px solid var(--gx-border);
      }

      .gx-swatch {
        position: relative;
        flex: none;
        display: inline-block;
        width: 22px;
        height: 10px;
        background: var(--gx-swatch, var(--gx-task));
        border-radius: 3px;
      }

      .gx-swatch--task {
        background: var(--gx-task);
      }

      .gx-swatch--progress {
        background: linear-gradient(to right, var(--gx-task-progress) 60%, var(--gx-task) 0);
      }

      .gx-swatch--project {
        background: var(--gx-project);
      }

      .gx-swatch--bracket {
        height: 5px;
        margin-bottom: 4px;
        background: var(--gx-project);
        border-radius: 1px 1px 0 0;
      }

      .gx-swatch--bracket::before,
      .gx-swatch--bracket::after {
        content: "";
        position: absolute;
        top: 100%;
        border-top: 5px solid var(--gx-project);
      }

      .gx-swatch--bracket::before {
        left: 0;
        border-right: 5px solid transparent;
      }

      .gx-swatch--bracket::after {
        right: 0;
        border-left: 5px solid transparent;
      }

      .gx-swatch--milestone {
        width: 9px;
        height: 9px;
        margin: 0 6px;
        background: var(--gx-milestone);
        border: 1px solid var(--gx-milestone-border);
        border-radius: 2px;
        transform: rotate(45deg);
      }

      .gx-swatch--critical {
        background: var(--gx-critical, #e11d48);
      }

      .gx-swatch--baseline {
        height: 5px;
        background: var(--gx-baseline, #94a3b8);
        opacity: 0.85;
      }

      .gx-swatch--deadline {
        width: 2px;
        height: 14px;
        margin: 0 10px 0 6px;
        background: var(--gx-deadline, #f59e0b);
        border-radius: 0;
      }

      .gx-swatch--deadline::before {
        content: "";
        position: absolute;
        top: 0;
        left: 0;
        width: 9px;
        height: 7px;
        background: var(--gx-deadline, #f59e0b);
        clip-path: polygon(0 0, 100% 50%, 0 100%);
      }

      .gx-swatch--overdue {
        background: var(--gx-task);
        box-shadow: inset 0 0 0 2px var(--gx-danger);
      }

      .gx-swatch--today {
        width: 2px;
        height: 14px;
        margin: 0 10px;
        background: var(--gx-accent);
        border-radius: 0;
      }

      .gx-swatch--committed {
        background: linear-gradient(to right, var(--gx-committed-progress) 45%, var(--gx-committed) 0);
        box-shadow: inset 0 0 0 1px var(--gx-committed-border);
      }

      .gx-swatch--not-committed {
        background: var(--gx-not-committed);
        box-shadow: inset 0 0 0 1px var(--gx-not-committed-border);
      }

      .gx-swatch--plan {
        width: 18px;
        height: 14px;
        background: var(--gx-plan-soft);
        border-inline: 1.5px solid var(--gx-plan);
        border-radius: 0;
      }

      .gx-swatch--dot {
        width: 10px;
        height: 10px;
        border-radius: 999px;
      }

      .gx-swatch--line {
        height: 3px;
      }

      .gx-legend-icon {
        display: inline-flex;
        color: var(--gx-muted);
      }

      .gx-legend-icon .gx-icon {
        width: 14px;
        height: 14px;
      }

      /* ------------------------------------------------------------- motion */
      @keyframes gx-fade {
        from { opacity: 0; }
      }

      @keyframes gx-tip {
        from { opacity: 0; transform: translateY(-4px); }
        to { opacity: 1; transform: none; }
      }

      @keyframes gx-pop {
        from { opacity: 0; transform: translateY(-4px) scale(0.98); }
      }

      @keyframes gx-rise {
        from { opacity: 0; transform: translateY(8px) scale(0.98); }
      }

      .gx-notice {
        animation-name: gx-notice-in;
      }

      @keyframes gx-notice-in {
        from { opacity: 0; transform: translate(-50%, 8px); }
      }

      @media (prefers-reduced-motion: reduce) {
        .gx-root *,
        .gx-root *::before,
        .gx-root *::after {
          animation: none !important;
          transition: none !important;
        }
      }

      /* -------------------------------------------------------------- print */
      @media print {
        .gx-root {
          border: 0;
          overflow: visible;
        }

        .gx-toolbar,
        .gx-notice,
        .gx-backdrop,
        .gx-popup,
        .gx-popover,
        .gx-actions,
        .gx-chip-remove,
        .gx-filter-bar .gx-text-btn,
        .gx-tooltip,
        .gx-link-point,
        .gx-handle,
        .gx-progress-handle {
          display: none !important;
        }

        .gx-viewport {
          height: auto;
          overflow: visible;
        }

        .gx-header,
        .gx-grid-head,
        .gx-grid {
          position: static;
          box-shadow: none;
        }

        .gx-bar-body,
        .gx-bar-progress,
        .gx-highlight,
        .gx-plan-band,
        .gx-scale-band,
        .gx-summary-cap,
        .gx-swatch,
        .gx-scale-cell--weekend {
          print-color-adjust: exact;
          -webkit-print-color-adjust: exact;
        }
      }
    </style>
    """
  end
end
