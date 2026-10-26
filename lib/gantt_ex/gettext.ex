defmodule GanttEx.Gettext do
  @moduledoc """
  The Gettext backend holding GanttEx translations.

  GanttEx ships with translations in `priv/gettext` for:
  English (`en`), Spanish (`es`), French (`fr`), Italian (`it`),
  German (`de`), Portuguese (`pt`), Brazilian Portuguese (`pt_BR`) and
  Japanese (`ja`).

  This backend is independent from your application's backend, so the Gantt
  locale is chosen per component with the `locale` attribute of
  `GanttEx.Live.Gantt` (see `GanttEx.I18n`).
  """
  use Gettext.Backend, otp_app: :gantt_ex
end
