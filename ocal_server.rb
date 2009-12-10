#!/usr/bin/ruby

# Oracle Calendar to iCal format
# ocal2ical - http://github.com/jcarr/ocal2ical/
# Jason Carr - jason.carr@gmail.com

require 'rubygems'
require 'ramaze'
require 'ocal'
require 'rexml/document'

class MainController < Ramaze::Controller
  map "/ocal"

  def get_ocal()
vcal_header = <<VCAL
BEGIN:VCALENDAR
PRODID:-//ocal2ical//ocal2cal 1.0//EN
VERSION:2.0
CALSCALE:GREGORIAN
METHOD:PUBLISH
X-WR-CALNAME:Oracle Calendar
X-WR-TIMEZONE:America/New_York
BEGIN:VTIMEZONE
TZID:America/New_York
X-LIC-LOCATION:America/New_York
BEGIN:DAYLIGHT
TZOFFSETFROM:-0500
TZOFFSETTO:-0400
TZNAME:EDT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
END:DAYLIGHT
BEGIN:STANDARD
TZOFFSETFROM:-0400
TZOFFSETTO:-0500
TZNAME:EST
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
END:STANDARD
END:VTIMEZONE
VCAL

vcal_footer = <<VCAL
END:VCALENDAR
VCAL

    auth = Rack::Auth::Basic::Request.new(request.env)
    if (auth.provided? && auth.basic?)
      username, password = auth.credentials
      puts "authentication success - #{username}"
    else
      puts "authentication failed!"
      respond("Authorization required", 401, "WWW-Authenticate" => 'Basic realm="ocal2ical - Oracle Calendar username/password"')
    end

    calendar = Array.new

    doc = REXML::Document.new(get_calendar(username,password))

    doc.elements.each('SyncML/SyncBody/Sync/Add/Item/Data') { |x|
      cal = CalendarEntry.new(x.text)
      calendar.push(cal)
    }

    if calendar.length == 0
      respond("Service Unavailable", 503)
      #return ''
    end

    out = vcal_header
    calendar.each { |cal|
      out += cal.to_ical
    }
    out += vcal_footer

    out
  end
end

Ramaze.start
