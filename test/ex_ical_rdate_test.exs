defmodule ExIcalRDATETest do
  use ExUnit.Case
  alias ExIcal.DateParser

  doctest ExIcal

  test "event with RDATE PERIOD" do
    ical = """
    BEGIN:VCALENDAR
    CALSCALE:GREGORIAN
    VERSION:2.0
    BEGIN:VEVENT
    DESCRIPTION:Let's go!\n\tWanna see Star Wars?\n\x20It's great
    DTEND:20221124T104500Z
    DTSTART:20221124T084500Z
    RRULE:FREQ=MONTHLY;UNTIL=20161224T083000Z
    RDATE;TZID=Europe/Berlin;VALUE=PERIOD:20230126T110000/20230126T130000,20230126T150000/20230126T170000,20230126T190000/20230126T210000
    SUMMARY:Film with Amy and Adam
    END:VEVENT
    END:VCALENDAR
    """

    events = ExIcal.parse(ical)

    assert events |> Enum.count() == 1

    event = events |> List.first()

    assert event.description == "Let's go!\nWanna see Star Wars?\nIt's great"
    assert event.summary == "Film with Amy and Adam"
    assert event.start == DateParser.parse("20221124T084500Z")
    assert event.end == DateParser.parse("20221124T104500Z")

    assert event.rdate === [
      %{
        start: DateParser.parse("20230126T110000", "Europe/Berlin"),
        end: DateParser.parse("20230126T130000", "Europe/Berlin")
      },
      %{
        start: DateParser.parse("20230126T150000", "Europe/Berlin"),
        end: DateParser.parse("20230126T170000", "Europe/Berlin")
      },
      %{
        start: DateParser.parse("20230126T190000", "Europe/Berlin"),
        end: DateParser.parse("20230126T210000", "Europe/Berlin")
      }
    ]
  end

  test "event with RDATE DATE-TIME" do
    ical = """
    BEGIN:VCALENDAR
    CALSCALE:GREGORIAN
    VERSION:2.0
    BEGIN:VEVENT
    DESCRIPTION:Let's go!\n\tWanna see Star Wars?\n\x20It's great
    DTEND:20221124T104500Z
    DTSTART:20221124T084500Z
    RRULE:FREQ=MONTHLY;UNTIL=20161224T083000Z
    RDATE;TZID=Europe/Berlin;VALUE=DATE-TIME:20230126T110000,20230126T150000,20230126T190000
    SUMMARY:Film with Amy and Adam
    END:VEVENT
    END:VCALENDAR
    """

    events = ExIcal.parse(ical)

    assert events |> Enum.count() == 1

    event = events |> List.first()

    assert event.description == "Let's go!\nWanna see Star Wars?\nIt's great"
    assert event.summary == "Film with Amy and Adam"
    assert event.start == DateParser.parse("20221124T084500Z")
    assert event.end == DateParser.parse("20221124T104500Z")

    assert event.rdate === [
      %{
        start: DateParser.parse("20230126T110000", "Europe/Berlin"),
        end: nil
      },
      %{
        start: DateParser.parse("20230126T150000", "Europe/Berlin"),
        end: nil
      },
      %{
        start: DateParser.parse("20230126T190000", "Europe/Berlin"),
        end: nil
      }
    ]
  end

  test "event with RDATE DATE" do
    ical = """
    BEGIN:VCALENDAR
    CALSCALE:GREGORIAN
    VERSION:2.0
    BEGIN:VEVENT
    DESCRIPTION:Let's go!\n\tWanna see Star Wars?\n\x20It's great
    DTEND:20221124T104500Z
    DTSTART:20221124T084500Z
    RRULE:FREQ=MONTHLY;UNTIL=20161224T083000Z
    RDATE:20230126
    SUMMARY:Film with Amy and Adam
    END:VEVENT
    END:VCALENDAR
    """

    events = ExIcal.parse(ical)

    assert events |> Enum.count() == 1

    event = events |> List.first()

    assert event.description == "Let's go!\nWanna see Star Wars?\nIt's great"
    assert event.summary == "Film with Amy and Adam"
    assert event.start == DateParser.parse("20221124T084500Z")
    assert event.end == DateParser.parse("20221124T104500Z")

    assert event.rdate === [
      %{
        start: DateParser.parse("20230126"),
        end: nil
      }
    ]
  end
end
