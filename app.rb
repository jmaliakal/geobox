require 'sinatra'
require 'dropbox_sdk'

# Get your app key and secret from the Dropbox developer website
APP_KEY = '9425ne8xh71dd7y'
APP_SECRET = 'o1ci751vhyohcxr'

# ACCESS_TYPE should be ':dropbox' or ':app_folder' as configured for your app
ACCESS_TYPE = :dropbox
session = DropboxSession.new(APP_KEY, APP_SECRET)

session.get_request_token

authorize_url = session.get_authorize_url

# make the user sign in and authorize this token
puts "AUTHORIZING", authorize_url
puts "Please visit this website and press the 'Allow' button, then hit 'Enter' here."
gets

# This will fail if the user didn't visit the above URL and hit 'Allow'
session.get_access_token

client = DropboxClient.new(session, ACCESS_TYPE)
puts "linked account:", client.account_info().inspect

get '/' do
	'Hello world!'
end