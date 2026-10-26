defmodule GanttEx.I18nTest do
  use ExUnit.Case, async: true

  alias GanttEx.I18n

  @translated I18n.locales() -- ["en"]

  describe "translations" do
    for locale <- @translated do
      test "#{locale} translates every message" do
        path =
          Path.join([
            :code.priv_dir(:gantt_ex),
            "gettext",
            unquote(locale),
            "LC_MESSAGES",
            "default.po"
          ])

        {:ok, po} = Expo.PO.parse_file(path)

        untranslated =
          for message <- po.messages,
              Expo.Message.has_flag?(message, "fuzzy") or blank?(message),
              do: Expo.Message.key(message)

        assert untranslated == []
      end
    end

    test "labels are complete and different from English" do
      english = I18n.labels("en")

      for locale <- @translated do
        labels = I18n.labels(locale)
        assert Map.keys(labels) == Map.keys(english)
        assert labels.save != english.save, "#{locale} save label is not translated"
      end
    end
  end

  test "formats month and weekday names for every locale" do
    for locale <- I18n.locales() do
      formatted = I18n.format(~N[2025-05-05 00:00:00], "%A %B", locale)
      assert String.length(formatted) > 3
    end

    assert I18n.format(~N[2025-05-05 00:00:00], :weekday_date, "ja") == "5月5日 月曜日"
    assert I18n.format(~N[2025-05-05 00:00:00], :weekday_date, "de") == "Montag, 5. Mai"
    assert I18n.format(~N[2025-05-05 00:00:00], :quarter, "it") == "T2"
  end

  test "pluralizes durations" do
    assert I18n.duration(1, :day, "fr") == "1 jour"
    assert I18n.duration(2, :week, "pt_BR") == "2 semanas"
    assert I18n.duration(5, :day, "ja") == "5日"
  end

  test "functions can be used as patterns" do
    assert I18n.format(~N[2025-05-05 00:00:00], &"W#{GanttEx.Dates.iso_week(&1)}", "en") == "W19"

    assert I18n.format(~N[2025-05-05 00:00:00], fn _date, locale -> locale end, "pt-BR") ==
             "pt_BR"

    assert I18n.format(nil, :date, "en") == ""
  end

  defp blank?(%Expo.Message.Singular{msgstr: msgstr}), do: IO.iodata_to_binary(msgstr) == ""

  defp blank?(%Expo.Message.Plural{msgstr: msgstr}),
    do: Enum.any?(msgstr, fn {_index, value} -> IO.iodata_to_binary(value) == "" end)
end
