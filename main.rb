# The driver. Defines the webserver and its endpoints.

require "./auth/auth.rb"
require "./core/profiles.rb"
require "./core/shelves.rb"
require "./core/volumes.rb"

require "json"
require "sinatra"
require "sinatra/cross_origin"
require "sinatra/namespace"

class Bookclub < Sinatra::Base # to_json should be done at the router level right?
  include Auth, Profiles, Shelves, Volumes

  # CORS
  configure do
    enable :cross_origin
    set :protection, except: %i[json_csrf]
  end

  before do
    response.headers["Access-Control-Allow-Methods"] = "GET, PATCH, POST, DELETE, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type, Accept, X-User-Email, X-Auth-Token"
    response.headers["Access-Control-Allow-Origin"] = "*"
  end

  options "*" do
    response.headers["Access-Control-Allow-Methods"] = "GET, PATCH, POST, DELETE, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type, Accept, X-User-Email, X-Auth-Token"
    response.headers["Access-Control-Allow-Origin"] = "*"
    200
  end

  # Webserver
  register Sinatra::Namespace
  namespace "/api/v1" do
    before { content_type :json }

    get "/volumes" do
      q = params[:q]
      get_volumes_result("/volumes", q)
    end

    get "/volumes/:volume_id" do |volume_id|
      get_volumes_result("/volumes/" + volume_id)
    end

    get "/nyt-top-ten" do
      get_nyt_top_10()
    end

    post "/register" do
      data = JSON.parse(request.body.read)
      username = data["username"]
      pw = data["password"]
      email = data["email"]
      begin
        register_user(username, pw, email).to_json
      rescue AuthError => e
        halt e.status_code, e.msg
      end
    end

    post "/login" do
      data = JSON.parse(request.body.read)
      username = data["username"]
      pw = data["password"]
      begin
        verify_user(username, pw)
      rescue AuthError => e
        halt e.status_code, e.msg
      end
    end

    post "/deactivate" do
      data = JSON.parse(request.body.read)
      access_token = data["access_token"]
      begin
        deactivate_token(access_token)
      rescue AuthError => e
        halt e.status_code, e.msg
      end
      "Successfully deleted token"
    end

    get "/user/:username" do |username|
      begin
        get_user(username)
      rescue AuthError => e
        halt e.status_code, e.msg
      end
    end

    get "/:user_id/protected_endpoint" do |user_id|
      # Placeholder for protected endpoints
      access_token = request.env["HTTP_AUTHORIZATION"]
      if access_token.nil?
        halt 400, "Missing Authorization header in request to protected endpoint"
      end

      access_token = access_token.sub("Bearer ", "")
      begin
        verify_token(user_id, access_token)
      rescue AuthError => e
        halt e.status_code, e.msg
      end
      "Successfully accessed data using correct credentials"
    end

    get "/:user_id/shelves" do |user_id| # not protected
      begin
        get_user_shelf(user_id)
      rescue AuthError => e
        halt e.status_code, e.msg
      end
    end

    patch "/:user_id/shelves/exclusive" do |user_id| # protected
      access_token = request.env["HTTP_AUTHORIZATION"]
      if access_token.nil?
        halt 400, "Missing Authorization header in request to protected endpoint"
      end

      access_token = access_token.sub("Bearer ", "")
      begin
        verify_token(user_id, access_token)
      rescue AuthError => e
        halt e.status_code, e.msg
      end

      data = JSON.parse(request.body.read)
      operation = data["op"]
      volume_id = data["volume_id"]
      to_shelf = data["to_shelf"]
      set_completed = data["set_completed"]
      begin
        modify_exclusive_shelves(user_id, operation, volume_id, to_shelf, set_completed)
      rescue ShelfOpError => e
        halt e.status_code, e.msg
      end
    end

    get "/:user_id/profile" do |user_id| # not protected
      begin
        get_profile(user_id)
      rescue ProfileError => e
        halt e.status_code, e.msg
      end
    end

    patch "/:user_id/profile" do |user_id| # protected
      access_token = request.env["HTTP_AUTHORIZATION"]
      if access_token.nil?
        halt 400, "Missing Authorization header in request to protected endpoint"
      end

      access_token = access_token.sub("Bearer ", "")
      begin
        verify_token(user_id, access_token)
      rescue ProfileError => e
        halt e.status_code, e.msg
      end

      data = JSON.parse(request.body.read)
      profile_fields = get_profile_fields()
      profile_updates = {}

      profile_fields.each do |field|
        if !data[field].nil?
          profile_updates[field] = data[field]
        end
      end
      update_profile_fields(user_id, profile_updates)
    end
  end
end
