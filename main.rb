require 'bundler'
Bundler.require(:default)

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

FILE_NAME = "ACT_0006"

puts "Processing #{FILE_NAME}"

omh = File.open("#{FILE_NAME}.OMH")
r  = OMH.read(omh)

omd = File.open("#{FILE_NAME}.OMD")

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


STRAVA_ACCESS_TOKEN = "YOUR_STRAVA_ACCESS_TOKEN"

strava = Strava::Api::V3::Client.new(:access_token => STRAVA_ACCESS_TOKEN)

options = {}
options[:activity_type] = 'ride'
options[:data_type] = 'gpx'


options[:file] =File.new("strava.gpx")

status = strava.upload_an_activity(options)
upload_id = status['id']

puts status[:status]
puts status

begin
sleep 1
status = strava.retrieve_upload_status(upload_id)
puts status[:status]
puts status
end while status[:status] !~ /ready/

File.delete("strava.gpx")


