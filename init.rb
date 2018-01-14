require 'bundler'
Bundler.require(:default)

CLIENT_SECRET="YOUR_STRAVA_CLIENT_SECRET"
CLIENT_ID="YOUR_CLIENT_ID"

if CLIENT_SECRET == 'YOUR_STRAVA_CLIENT_SECRET'
	puts "YOU DIDN'T SET YOU CLIENT SECRET"
	exit
end

if CLIENT_ID == 'YOUR_CLIENT_ID'
	puts "YOU DIDN'T SET YOU CLIENT ID"
	exit
end

Launchy.open("https://www.strava.com/oauth/authorize?client_id=10029&response_type=code&redirect_uri=http://localhost:4567/token_exchange&scope=write&approval_prompt=force");

get '/token_exchange' do
  code = params[:code]

  res = HTTParty.post('https://www.strava.com/oauth/token', body: {
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET,
    code: code    
  })
  
  token = res["access_token"]
  puts "Access token: #{token}"

  File.open("token", 'w') { |file| file.write(token) }

  Sinatra::Application.quit!
  "installed, you can close this tab and run main.rb"
end

