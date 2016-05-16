require 'bundler'
Bundler.require(:default)

Launchy.open("https://www.strava.com/oauth/authorize?client_id=10029&response_type=code&redirect_uri=http://localhost:4567/token_exchange&scope=write&approval_prompt=force");

CLIENT_SECRET="YOUR_STRAVA_CLIENT_SECRET"

get '/token_exchange' do
  code = params[:code]

  res = HTTParty.post('https://www.strava.com/oauth/token', body: {
    client_id: 10029,
    client_secret: CLIENT_SECRET,
    code: code    
  })
  
  token = res["access_token"]
  puts "Access token: #{token}"

  File.open("token", 'w') { |file| file.write(token) }

  Sinatra::Application.quit!
  "installed, you can close this tab and run main.rb"
end

