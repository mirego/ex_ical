defmodule ExIcal.Parser do
  @moduledoc """
  Responsible for parsing an iCal string into a list of events.

  This module contains one public function, `parse/1`.

  Most of the most frequently used iCalendar properties can be parsed from the
  file (for example: start/end time, description, recurrence rules, and more;
  see `ExIcal.Event` for a full list).

  However, there is not yet full coverage of all properties available in the
  iCalendar spec. More properties will be added over time, but if you need a
  legal iCalendar property that `ExIcal` does not yet support, please sumbit an
  issue on GitHub.
  """

  alias ExIcal.{DateParser,Event}

  @doc """
  Parses an iCal string into a list of events.

  This function takes a single argument–a string in iCalendar format–and returns
  a list of `%ExIcal.Event{}`.

  ## Example

  ```elixir
  HTTPotion.get("url-for-icalendar").body
    |> ExIcal.parse
    |> ExIcal.by_range(DateTime.utc_now(), DateTime.utc_now() |> Timex.shift(days: 7))
  ```
  """

  @spec parse(String.t) :: [%Event{}]
  def parse(data) do
    data
    |> format()
    |> Enum.reduce(%{events: []}, fn(line, data) ->
      line
      |> String.trim()
      |> parse_line(data)
    end)
    |> Map.get(:events)
  end

  defp format(data) do
    data
    |> String.replace(~s"\n\t", ~S"\n")
    |> String.replace(~s"\n\x20", ~S"\n")
    |> String.replace(~s"\"", "")
    |> String.split("\n")
    |> Enum.reject(& &1 === "")
    |> Enum.reduce([], & maybe_merge_line_with_previous/2)
    |> Enum.reverse()
  end

  defp maybe_merge_line_with_previous(line, []), do: [line]
  defp maybe_merge_line_with_previous(line, [previous | rest] = acc) do
    if Regex.match?(~r/^[A-Z]+:|;/, line) do
      [line | acc]
    else
      [(previous <> line) | rest]
    end
  end

  defp parse_line("BEGIN:VEVENT" <> _, data),           do: %{data | events: [%Event{} | data[:events]]}
  defp parse_line("DTSTART" <> start, data),            do: data |> put_to_map(:start, process_date(start, data[:tzid]))
  defp parse_line("DTEND" <> endd, data),               do: data |> put_to_map(:end, process_date(endd, data[:tzid]))
  defp parse_line("DTSTAMP" <> stamp, data),            do: data |> put_to_map(:stamp, process_date(stamp, data[:tzid]))
  defp parse_line("SUMMARY:" <> summary, data),         do: data |> put_to_map(:summary, process_string(summary))
  defp parse_line("DESCRIPTION:" <> description, data), do: data |> put_to_map(:description, process_string(description))
  defp parse_line("UID:" <> uid, data),                 do: data |> put_to_map(:uid, uid)
  defp parse_line("RRULE:" <> rrule, data),             do: data |> put_to_map(:rrule, process_rrule(rrule, data[:tzid]))
  defp parse_line("RDATE" <> rdate, data),              do: data |> put_to_map(:rdate,  rdate |> sanitize_rdate() |> process_rdate(data[:tzid]))
  defp parse_line("TZID:" <> tzid, data),               do: data |> Map.put(:tzid, tzid)
  defp parse_line("CATEGORIES:" <> categories, data),   do: data |> put_to_map(:categories, String.split(categories, ","))
  defp parse_line(_, data), do: data

  defp put_to_map(%{events: [event | events]} = data, key, value) do
    updated_event = %{event | key => value}
    %{data | events: [updated_event | events]}
  end
  defp put_to_map(data, _key, _value), do: data

  defp process_date(":" <> date, tzid), do: DateParser.parse(date, tzid)
  defp process_date(";" <> date, _) do
    [timezone, date] = date |> String.split(":")
    timezone = case timezone do
      "TZID=" <> timezone -> timezone
      _ -> nil
    end
    DateParser.parse(date, timezone)
  end

  defp process_rrule(rrule, tzid) do
    rrule |> String.split(";") |> Enum.reduce(%{}, fn(rule, hash) ->
      [key, value] = rule |> String.split("=")
      case key |> String.downcase |> String.to_atom do
        :until    -> hash |> Map.put(:until, DateParser.parse(value, tzid))
        :interval -> hash |> Map.put(:interval, String.to_integer(value))
        :count    -> hash |> Map.put(:count, String.to_integer(value))
        :freq     -> hash |> Map.put(:freq, value)
        _         -> hash
      end
    end)
  end

  defp sanitize_rdate(rdate) do
    ~r/\s+/
    |> Regex.replace(rdate, "")
    |> String.replace(~S"\n", "")
  end

  defp process_rdate(":" <> date, tzid), do: parse_rdate_dates([date], tzid)

  defp process_rdate(";" <> rdate_value, _) do
    [rtdparams, rtdvals] = rdate_value |> String.split(":")

    splitted_rtdparams = String.split(rtdparams, ";")

    timezone = Enum.find_value(splitted_rtdparams, fn param ->
      case param do
        "TZID=" <> timezone -> timezone
        _ -> nil
      end
    end)

    value_type = Enum.find_value(splitted_rtdparams, fn param ->
      case param do
        "VALUE=" <> value_type -> value_type
        _ -> nil
      end
    end)

    case value_type do
      "PERIOD" -> rtdvals |> String.split(",") |> parse_rdate_period_dates(timezone)
      "DATE-TIME" -> rtdvals |> String.split(",") |> parse_rdate_dates(timezone)
      "DATE" -> rtdvals |> String.split(",") |> parse_rdate_dates(timezone)
      _ -> []
    end
  end

  defp parse_rdate_period_dates(period_dates, timezone) do
    Enum.map(period_dates, fn period ->
      [start_date, end_date] = String.split(period, "/")

      %{
        start: DateParser.parse(start_date, timezone),
        end: DateParser.parse(end_date, timezone)
      }
    end)
  end

  defp parse_rdate_dates(dates, timezone) do
    Enum.map(dates, fn date ->
      %{
        start: DateParser.parse(date, timezone),
        end: nil
      }
    end)
  end

  defp process_string(string) when is_binary(string) do
    string
    |> String.replace(~S",", ~s",")
    |> String.replace(~S"\n", ~s"\n")
  end
end
