require 'sinatra'
require 'dropbox_sdk'

# Get your app key and secret from the Dropbox developer website
APP_KEY = '9425ne8xh71dd7y'
APP_SECRET = 'o1ci751vhyohcxr'

# -------------------------------------------------------------------
# OAuth (using OAuth v2):

def get_web_auth()
	return DropboxOAuth2Flow.new(APP_KEY, APP_SECRET, url('/OAuth-finish'),
								 session, :dropbox_auth_csrf_token)
end

get '/OAuth-start' do 
	authorize_url = get_web_auth().start()

	redirect authorize_url
end

get '/OAuth-finish' do
	begin
        access_token, user_id, url_state = get_web_auth.finish(params)
    rescue DropboxOAuth2Flow::BadRequestError => e
        return html_page "Error in OAuth 2 flow", "<p>Bad request to /dropbox-auth-finish: #{e}</p>"
    rescue DropboxOAuth2Flow::BadStateError => e
        return html_page "Error in OAuth 2 flow", "<p>Auth session expired: #{e}</p>"
    rescue DropboxOAuth2Flow::CsrfError => e
        logger.info("/dropbox-auth-finish: CSRF mismatch: #{e}")
        return html_page "Error in OAuth 2 flow", "<p>CSRF mismatch</p>"
    rescue DropboxOAuth2Flow::NotApprovedError => e
        return html_page "Not Approved?", "<p>Why not, bro?</p>"
    rescue DropboxOAuth2Flow::ProviderError => e
        return html_page "Error in OAuth 2 flow", "Error redirect from Dropbox: #{e}"
    rescue DropboxError => e
        logger.info "Error getting OAuth 2 access token: #{e}"
        return html_page "Error in OAuth 2 flow", "<p>Error getting access token</p>"
    end

    # Currently storing auth token in session
    session[:access_token] = access_token
    redirect url('/')
end

get '/dropbox-unlink' do
	session.delete(:access_token)
	nil # <--- What does this line do??
end

# If we've already authorized a session, return DropboxClient object
def get_dropbox_client
	if session[:access_token]
		return DropboxClient.new(session[:access_token])
	end
end

# -------------------------------------------------------------------

get '/' do
	# Get DropboxClient object
	client = get_dropbox_client
	unless client
		redirect url("/OAuth-start")
	end

	# Get DropboxClient.metadata
	path = params[:path] || '/'
	begin
		entry = client.metadata(path)
	rescue DropboxAuthError = e
		# Auth error means the access token is likely bad
		session.delete(:access_token)
		logger.info "Dropbox auth error: #{e}"
		return html_page "Dropbox auth error"
	rescue DropboxError => e
		if e.http_response.code == '404'
			return html_page "Path not found #{h path}" # <--- What's {h path}?
		else
			logger.info "Dropbox API error: #{e}"
			return html_page "Dropbox API error"
		end
	end

	if entry['is_dir']
		render_folder(client, entry)
	else
		render_file(client,entry)
end

# -------------------------------------------------------------------

def html_page(title, body='')
    "<html>" +
        "<head><title>#{h title}</title></head>" +
        "<body><h1>#{h title}</h1>#{body}</body>" +
    "</html>"
end

# Rack will issue a warning if no session secret key is set.  A real web app would not have
# a hard-coded secret in the code but would load it from a config file.
use Rack::Session::Cookie, :secret => 'dummy_secret'

set :port, 5000
enable :sessions

helpers do
    include Rack::Utils
    alias_method :h, :escape_html
end
# -------------------------------------------------------------------

if APP_KEY == '' or APP_SECRET == ''
    puts "You must set APP_KEY and APP_SECRET at the top of \"#{__FILE__}\"!"
    exit 1
end