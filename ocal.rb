#!/usr/bin/ruby

# Oracle Calendar to iCal format
# ocal2ical - http://github.com/jcarr/ocal2ical/
# Jason Carr - jason.carr@gmail.com


require 'rubygems'
require 'httpclient'
require 'rexml/document'
require 'date'
require 'digest'

def get_calendar(username,password)
  authentication_key = [sprintf("%s:%s",username,password)].pack('m').chop
  session_id = Digest::MD5.hexdigest(rand(1024*1024*1024*1024).to_s).upcase + 'A'
  location = "./Calendar/events"

  # You'll want to change this to your Oracle Calendar server and location
  uri = 'https://ocal.server.com/ocst-bin/ocas.fcgi'

  options = {'Connection' => 'close', 'Content-Type' => 'application/vnd.syncml+xml', 'User-Agent' => 'ocal2ical/1.0'}
  
  body = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><SyncML xmlns='SYNCML:SYNCML1.1'><SyncHdr><VerDTD>1.1</VerDTD><VerProto>SyncML/1.1</VerProto><SessionID>#{session_id}</SessionID><MsgID>1</MsgID><Target><LocURI>#{uri}</LocURI></Target><Source><LocURI>IMEI:12345678901234567</LocURI></Source><Cred><Meta><Format xmlns='syncml:metinf'>b64</Format><Type xmlns='syncml:metinf'>syncml:auth-basic</Type></Meta><Data>#{authentication_key}</Data></Cred><Meta><MaxMsgSize xmlns='syncml:metinf'>204800</MaxMsgSize></Meta></SyncHdr><SyncBody><Alert><CmdID>1</CmdID><Data>201</Data><Item><Target><LocURI>#{location}</LocURI></Target><Source><LocURI>./MacCalendar</LocURI></Source><Meta><Anchor xmlns='syncml:metinf'><Last>20091003T181938Z</Last><Next>20091003T181938Z</Next></Anchor><MaxObjSize xmlns='syncml:metinf'>204800</MaxObjSize></Meta></Item></Alert><Final/></SyncBody></SyncML>"

  client = HTTPClient.new

  res = client.post(uri, body, options)

  body = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><SyncML xmlns='SYNCML:SYNCML1.1'><SyncHdr><VerDTD>1.1</VerDTD><VerProto>SyncML/1.1</VerProto><SessionID>#{session_id}</SessionID><MsgID>2</MsgID><Target><LocURI>#{uri}</LocURI></Target><Source><LocURI>IMEI:12345678901234567</LocURI></Source><Meta><MaxMsgSize xmlns='syncml:metinf'>204800</MaxMsgSize></Meta></SyncHdr><SyncBody><Status><CmdID>2</CmdID><MsgRef>1</MsgRef><CmdRef>0</CmdRef><Cmd>SyncHdr</Cmd><TargetRef>IMEI:12345678901234567</TargetRef><SourceRef>#{uri}</SourceRef><Data>200</Data></Status><Status><CmdID>3</CmdID><MsgRef>1</MsgRef><CmdRef>3</CmdRef><Cmd>Alert</Cmd><TargetRef>./MacCalendar</TargetRef><SourceRef>#{location}</SourceRef><Data>200</Data><Item><Target><LocURI>./MacCalendar</LocURI></Target><Source><LocURI>#{location}</LocURI></Source><Meta><Anchor xmlns='syncml:metinf'><Last>20091003T141625Z</Last><Next>20091003T141938Z</Next></Anchor></Meta></Item></Status><Sync><CmdID>5</CmdID><Target><LocURI>#{location}</LocURI></Target><Source><LocURI>./MacCalendar</LocURI></Source><NumberOfChanges>0</NumberOfChanges></Sync><Final/></SyncBody></SyncML>"

  res = client.post(uri, body, options)

  res.body.content
end



class CalendarEntry
  attr_reader :uid, :subject, :location, :date_start, :date_end, :length, :description
  
  def initialize(body)
    parse_vcal(body)
  end

  def frac_to_time(fr)
    ss,  fr = fr.divmod(Rational(1, 86400)) # 4p
    h,   ss = ss.divmod(3600)
    min, s  = ss.divmod(60)
    return h, min, s, fr
  end

  def parse_vcal(body)
    body.gsub!("=\n","")
    body.gsub!("=20"," ")

#    puts "======="
#    puts body
#    puts "======="

    # parse subject
    body =~ /UID:(.*)\nSUMMARY;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:(.*)\nLOCATION;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:(.*)\nDESCRIPTION;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:(.*)\nDTSTART:(.*)\nDTEND:(.*)\nEND:VEVENT/m
    @uid = $1
    @subject = $2
    @location = $3.chomp(' ')
    @description = $4
    @date_start = $5
    @date_end = $6

    hours, minutes, seconds, frac = frac_to_time(DateTime.parse(@date_end) - DateTime.parse(@date_start))
    #t= "#{hours} hours, #{minutes} minutes, #{seconds} seconds"
    @length = hours
  end
  
  def to_ical
    s = ""
    
    s += "BEGIN:VEVENT\n"
    #s += "STATUS:TENTATIVE\n"
    s += "STATUS:CONFIRMED\n"
#   DTSTART;VALUE=DATE:20060515
#   DTEND;VALUE=DATE:20060516
    if @length >= 24
      ds = @date_start[0..7]
      de = @date_end[0..7]
      s += "DTSTART;VALUE=DATE:#{ds}\n"
      s += "DTEND;VALUE=DATE:#{de}\n"
    else
      s += "DTSTART:" + @date_start + "\n"
      s += "DTEND:" + @date_end + "\n"
    end
    
    s += "UID:" + @uid + "\n"
    s += "DESCRIPTION:" + @description + "\n"
    s += "LOCATION:" + @location + "\n"
    s += "SUMMARY:" + @subject + "\n"
    s += "END:VEVENT\n"
   
    puts "===="
    puts s
    puts "===="

    s
  end
end

