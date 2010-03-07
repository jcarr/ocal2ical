#!/usr/bin/ruby

require 'rubygems'
require 'httpclient'
require 'rexml/document'
require 'date'
require 'digest'


def soapEnv(header="",body="")
  env = <<LOL
<?xml version='1.0' encoding='UTF-8'?>
<SOAP-ENV:Envelope
xmlns:SOAP-ENV='http://schemas.xmlsoap.org/soap/envelope/'
xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'
xmlns:xsd='http://www.w3.org/2001/XMLSchema'>
<SOAP-ENV:Header>
%s</SOAP-ENV:Header>
<SOAP-ENV:Body>
%s</SOAP-ENV:Body>
</SOAP-ENV:Envelope>
LOL
  return sprintf(env,header,body)
end

def soapHeader(username,password)
  return sprintf("<auth:BasicAuth xmlns:auth='http://soap-authentication.org/2002/01/'><Name>%s</Name><Password>%s</Password></auth:BasicAuth>",username,password)
end

def search(startTime,endTime)
body = <<BODY
  <cwsl:Search xmlns:cwsl="http://www.oracle.com/WebServices/Calendaring/1.0/">
  <CmdId>1</CmdId>
  <vQuery>
    <From>VEVENT</From>
    <Where>DTEND &gt;= '%s' AND DTSTART &lt;= '%s'</Where>
  </vQuery>
</cwsl:Search>
BODY
  
  return sprintf(body,startTime.strftime('%Y%m%dT%H%M%SZ'),endTime.strftime('%Y%m%dT%H%M%SZ'))
end

def soapCall(action,envelope,url)
  namespace='http://www.oracle.com/WebServices/Calendaring/1.0/'
  headers = {
    'Content-type' => 'text/xml; charset="UTF-8"',
    'SOAPAction' => sprintf('"%s%s"',namespace,action)
  }
  
  clnt = HTTPClient.new
  result = clnt.post(url,envelope,headers)
  result.body.content
end


def get_calendar(username,password,url)
  t1 = Date.parse(Time.now.strftime('%Y/%m/%d 00:00:00')).to_time
  t2 = t1+(86400*7)

  result = soapCall("Search",soapEnv(soapHeader(username,password),search(t1,t2)),url)

  result
end

class CalendarEntry
  attr_reader :uid, :subject, :location, :date_start, :date_end, :length, :description
  
  def initialize(body)
    #parse_vcal(body)
    parse_xml(body)
  end

  def parse_xml(body)
    o = Hash.new
    body.elements.each { |x|
      o[x.name]=Hash.new
      o[x.name][:text] = x.text
      if o[x.name][:text] == nil
        o[x.name][:text]=""
      end
      o[x.name][:attr] = Hash.new
      x.attributes.each { |k,v|
        o[x.name][:attr][k] = v
      }
    }

    @uid = o['uid'][:text]
    @subject = o['summary'][:text]
    @location = o['location'][:text]
    @date_start = o['dtstart'][:text]
    @date_end = o['dtend'][:text]
    hours, minutes, seconds, frac = frac_to_time(DateTime.parse(@date_end) - DateTime.parse(@date_start))
    @length = hours
    @description = o['description'][:text]
  end

  def frac_to_time(fr)
    ss,  fr = fr.divmod(Rational(1, 86400)) # 4p
    h,   ss = ss.divmod(3600)
    min, s  = ss.divmod(60)
    return h, min, s, fr
  end

  def to_ical
    s = ""
    
    s += "BEGIN:VEVENT\n"
    #s += "STATUS:TENTATIVE\n"
    s += "STATUS:CONFIRMED\n"
    if ((@length >= 24) || (@length == 0))
      ds = @date_start[0..7]
      de = @date_end[0..7]
      s += "DTSTART;VALUE=DATE:#{ds}\n"
      s += "DTEND;VALUE=DATE:#{de}\n"
    else
      s += "DTSTART:" + @date_start + "\n"
      s += "DTEND:" + @date_end + "\n"
    
#      s += "BEGIN:VALARM\n"
#      s += "ACTION:DISPLAY\n"
#      s += "DESCRIPTION:REMINDER\n"
#      s += "TRIGGER;RELATED=START:-PT10M\n"
#      s += "END:VALARM\n"
    end
    
    s += "UID:" + @uid + "\n"
    s += "DESCRIPTION:" + @description + "\n"
    s += "LOCATION:" + @location + "\n"
    s += "SUMMARY:" + @subject + "\n"


    # attendee list does show up on iphone but we don't get this via ocal :(
    #s += "ATTENDEE;MEMBER=\"mailto:ietf-calsch@example.org\":mailto:jsmith@example.com\n"
    #s += "ATTENDEE;PARTSTAT=DECLINED:mailto:jsmith@example.com\n"

    s += "END:VEVENT\n"

    s
  end
end

