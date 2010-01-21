require 'rubygems'
require 'ramaze'
require 'ocal-soap'
require 'rexml/document'


class MainController < Ramaze::Controller
  map "/ocal"

  def get_ocal()
    url = "https://calendar.andrew.cmu.edu/ocws-bin/ocas.fcgi"

vcal_header = <<VCAL
BEGIN:VCALENDAR
PRODID:-//Jason Carr//Jason Carr 1.0//EN
VERSION:2.0
CALSCALE:GREGORIAN
METHOD:PUBLISH
X-WR-CALNAME:Jason Carr
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
      puts "authentication as #{username}"
    else
      puts "authentication not passed, requesting via 401"
      respond("Authorization required", 401, "WWW-Authenticate" => 'Basic realm="OCal CorpSync Password"')
    end

    calendar = Array.new

    result = get_calendar(username,password,url)

    doc = REXML::Document.new(result)

    doc.elements.each('/soap:Envelope/soap:Body/cwsl:Reply/iCalendar/vcalendar/vevent') { |x|
      cal = CalendarEntry.new(x)
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
