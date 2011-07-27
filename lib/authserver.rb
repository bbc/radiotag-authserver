class AuthServer < Sinatra::Base
  def logger
    @logger ||= Logger.new(env['rack.errors'])
    @logger.progname = File.basename(__FILE__)
    @logger
  end

  helpers do
    def expect_param(key)
      key = key.to_s
      if params.key?(key)
        params[key]
      else
        halt 400, "Missing param: #{key}"
      end
    end
  end

  get '/auth' do
    if token = Token.first(:token => params['token'])
      status 200
      token.to_json
    else
      status 404
    end
  end

  post '/auth' do
    if params["registration_key"]
      registration_key   = expect_param("registration_key")
      pin                = expect_param("pin")

      token_str = registration_key
      if token = Token.first(:token => token_str)
        if token.value["pin"] == pin
          new_token = Token.create(:value => token.value)
          new_token.save

          status 201
          { "token" => new_token.token }.to_json
        else
          status 401
        end
      else
        status 401
      end
    elsif grant = params["grant"]
      if token = Token.first_or_create(:value => grant)
        status 201
        { "token" => token.token }.to_json
      else
        status 400
      end
    elsif tok = params["token"]
      if token = Token.first_or_create(:token => tok, :value => params["value"])
        status 201
        { "token" => token.token }.to_json
      else
        status 400
      end
    else
      status 400
    end
  end

  post '/authorized' do
    rv = :unauthorized
    if token = params["token"]
      if token = Token.first(:token => token)
        rv = :authorized
      end
    elsif grant = params["grant"]
      if token = Token.first(:token => grant["token"])
        rv = :authorized
      end
    end
    case rv
    when :unauthorized
      halt 401, "Unauthorized"
    when :authorized
      [200, { "token" => token.token }.to_json + "\n"]
    end
  end

  post '/assoc' do
    registration_key = expect_param(:registration_key)
    id               = expect_param(:id)

    # Assume account_id valid
    pin = GenerateID.rand_pin
    token = registration_key
    if Token.first(:token => token)
      # already registered this device
      status 400
    else
      if user = User.first(:id => id)
        token_record = Token.create(:token => token,
                                    :value =>
                                    {
                                      :account_id   => user.id,
                                      :account_name => user.name,
                                      :pin          => pin
                                    })
        if token_record
          # TODO
          status 201
          { :pin => pin }.to_json + "\n"
        else
          status 500
        end
      else
        status 401
      end
    end
  end

  post '/account' do
    name = expect_param(:name)
    id = params[:id]

    # Assume id valid
    if User.first(:id => id)
      status 401
      "User already exists"
    else
      user = User.create(:id   => id,
                         :name => name)
      if user
        # TODO
        status 201
        user.to_json + "\n"
      else
        status 500
      end
    end
  end

  get '/account' do
    id = expect_param(:id)

    # Assume id valid
    if user = User.first(:id => id)
      status 200
      user.to_json + "\n"
    else
      status 404
    end
  end

  delete '/account' do
    id = expect_param(:id)

    # Assume id valid
    if user = User.first(:id => id)
      result = user.to_json + "\n"
      user.destroy!
      status 200
      result
    else
      status 404
    end
  end


end
