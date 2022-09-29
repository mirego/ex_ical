defmodule ExIcal.DateFormatsTest do
  use ExUnit.Case
  import ExIcal.Test.Utils

  def ical(dtstart, tzid \\ nil) do
    """
    BEGIN:VCALENDAR#{if tzid, do: "\nTZID:#{tzid}"}
    BEGIN:VEVENT
    #{dtstart}
    END:VEVENT
    END:VCALENDAR
    """
  end

  # Set up test scenarios

  date_match     = %{year: 1969, month: 6, day: 20}
  datetime_match = %{year: 1969, month: 6, day: 20,
                     hour: 20, minute: 18, second: 4}
  chicago_tzmatch  = "America/Chicago"
  berlin_tzmatch   = "Europe/Berlin"
  utc_tzmatch      = "UTC"

  allowed_date_formats = [
    #---------------------------------------------+---------------+----------------------------------+
    #                               DTSTART input |   Parsed Date |  Timezone with Global TZID = ?   |
    #                                             |               |            nil | America/Chicago |
    #---------------------------------------------+---------------+----------------+-----------------+
    {                           "DTSTART:19690620",     date_match,    utc_tzmatch,  chicago_tzmatch},
    {                          "DTSTART:19690620Z",     date_match,    utc_tzmatch,     utc_tzmatch,},
    {                    "DTSTART:19690620T201804", datetime_match,    utc_tzmatch, chicago_tzmatch,},
    {                   "DTSTART:19690620T201804Z", datetime_match,    utc_tzmatch,     utc_tzmatch,},
    { "DTSTART;TZID=Europe/Berlin:19690620T201804", datetime_match, berlin_tzmatch,  berlin_tzmatch,},
    {"DTSTART;TZID=Europe/Berlin:19690620T201804Z", datetime_match,    utc_tzmatch,     utc_tzmatch,},
  ]

  # Test cases

  for {dtstart, date_match, no_tzid, global_tzid} <- allowed_date_formats do
    @tag dtstart: dtstart
    @tag date_match: date_match
    @tag timezone: no_tzid
    test ~s("#{dtstart}" with no global tzid),
         %{dtstart: dtstart, date_match: date_match, timezone: timezone} do
      [event | _] = dtstart
                    |> ical
                    |> ExIcal.parse
      assert_subset date_match, event.start
      assert_subset timezone, event.start.time_zone
    end

    @tag dtstart: dtstart
    @tag date_match: date_match
    @tag timezone: global_tzid
    @tag tzid: tzid = "America/Chicago"
    test ~s("#{dtstart}" with global "TZID:#{tzid}"),
         %{dtstart: dtstart, date_match: date_match, timezone: timezone, tzid: tzid} do
      [event | _] = dtstart
                    |> ical(tzid)
                    |> ExIcal.parse
      assert_subset date_match, event.start
      assert_subset timezone, event.start.time_zone
    end
  end
end
