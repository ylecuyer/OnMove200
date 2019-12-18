require 'bundler'
require 'open-uri'
Bundler.require(:main)

include GPX

class OMH < BinData::Record
  endian :little

  uint32 :distance
  uint16 :duration
  uint16 :avgSpeed
  uint16 :maxSpeed
  uint16 :totalKcal
  uint8 :averageHr
  uint8 :maximumHr
  uint8 :year
  uint8 :month
  uint8 :day
  uint8 :hour
  uint8 :minutes
  uint8 :activityId1

  uint16 :pointsCount
  uint8 :indoor
  buffer :reserved2, length: 15, type: :uint8
  uint8 :activityId2
  uint8 :dataId2

  uint16 :timeBelow
  uint16 :timeIn
  uint16 :timeAbove
  uint16 :speedLimitLow
  uint16 :speedLimitHigh
  uint8 :hrLimitLow
  uint8 :hrLimitHigh
  uint8 :target
  buffer :reserved3, length: 5, type: :uint8
  uint8 :activityId3
  uint8 :dataId3
end

def OMD_Type(io)
  io.seek(19, IO::SEEK_CUR)
  b = io.readbyte
  io.seek(-20, IO::SEEK_CUR)
  return b
end

OMD_GPS_TYPE = 0xF1
OMD_CURVE_TYPE = 0xF2

class Latlng < BinData::Primitive
  int32le :latlng

  def set(val)
    self.latlng = val.to_i
  end

  def get
    (self.latlng/1000000.0).round(5)
  end
end

class OMD_GPS < BinData::Record
  endian :little

  latlng :latitude
  latlng :longitude
  uint32 :distance
  uint16 :stopWatch
  uint8 :gpsStatus
  buffer :reserved, length: 4, type: :uint8
  uint8 :dataId
end

class OMD_CURVE < BinData::Record
  endian :little

  uint16 :stopWatch
  uint16 :speed
  uint16 :kcal
  uint8 :hr
  uint8 :lap
  uint8 :cad
  uint8 :padByte

  uint16 :stopWatch2
  uint16 :speed2
  uint16 :kcal2
  uint8 :hr2
  uint8 :lap2
  uint8 :cad2
  uint8 :dataId
end

unless File.exist?("token")
  puts "First run init.rb"
  exit
end

STRAVA_ACCESS_TOKEN = File.open("token", "rb").read
strava = Strava::Api::Client.new(access_token: STRAVA_ACCESS_TOKEN)

cli = HighLine.new

path = cli.ask("OnMove200 path?") { |q| q.default = "/media/ylecuyer/ONMOVE-200" }

Dir.chdir("#{path}/DATA")

files = Dir["*.OMD"]

puts "#{files.count} files found #{files}"

files.each do |file|
  filename = File.basename(file, ".OMD")

  puts ""
  puts "Processing #{filename}"

  omh = File.open("#{path}/DATA/#{filename}.OMH")
  r  = OMH.read(omh)

  omd = File.open("#{path}/DATA/#{filename}.OMD")

  frames = omd.size/20

  puts "File contains #{frames} frames"

  progressbar = ProgressBar.create(:title => "Frames", :total => frames)

  t = (Time.new(r.year+2000, r.month, r.day, r.hour, r.minutes, 00) - r.duration).utc

  gpx = GPXFile.new
  track = Track.new(:name => "OnMove200 - #{r.day}/#{r.month}/#{r.year+2000}")
  segment = Segment.new

  (0..frames-1).each do

    omd_type = OMD_Type(omd)

    case omd_type
    when OMD_GPS_TYPE
      d = OMD_GPS.read(omd)
      segment.points <<  TrackPoint.new({lat: d.latitude, lon: d.longitude, time: t+d.stopWatch})
    when OMD_CURVE_TYPE
      d = OMD_CURVE.read(omd)
    end

    progressbar.increment
  end

  track.segments << segment
  gpx.tracks << track
  gpx.write("strava.gpx")

  options = {}
  options[:activity_type] = 'ride'
  options[:data_type] = 'gpx'
  options[:commute] = ENV['COMMUTE'] || false
  options[:external_id] = file

  options[:file] = Faraday::UploadIO.new('strava.gpx', 'application/gpx+xml')

  upload = begin
             strava.create_upload(options)
           rescue Strava::Errors::Fault => e
             if e.error =~ /duplicate of activity/
               puts "SKIPING because:"
               puts e.status
               puts e.error
               next
             end

             raise e
           end

  puts upload.status

  begin
    sleep 1
    res = strava.upload(upload.id)
    puts res.status
  end while res.status !~ /ready/

  File.delete("strava.gpx")
end

puts ""

cli.choose do |menu|
  menu.prompt = "Clean rides?"
  menu.choice(:yes) do
    files.each do |file|
      filename = File.basename(file, ".OMD")
      File.delete("#{path}/DATA/#{filename}.OMH")
      File.delete("#{path}/DATA/#{filename}.OMD")
    end
  end
  menu.choices(:no)
end

if File.exist?("#{path}/epo.7")
  modification_time = File.mtime("#{path}/epo.7")
  days_ago = ((Time.now - modification_time)/86400).to_i
  days_ago_msg = case days_ago when 0 then "today" when 1 then "yesterday" else "#{days_ago} days ago" end

  puts "epo.7 last update: #{days_ago_msg} (#{modification_time})"
  puts ">> YOU SHOULD UPDATE <<" if days_ago > 7
else
  puts "epo.7 not present"
  puts ">> YOU SHOULD UPDATE <<"
end

  cli.choose do |menu|
    menu.prompt = "Update epo.7?"
    menu.choice(:yes) do
      puts "Downloading epo.7..."
      download = open('https://s3-eu-west-1.amazonaws.com/ephemeris/epo.7')
      IO.copy_stream(download, "#{path}/epo.7")
      puts "Done"
    end
    menu.choices(:no)
  end
