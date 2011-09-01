ENV['RACK_ENV'] = 'test'

# add require_relative
unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

require_relative '../lib/init'
require_relative '../lib/authserver'
require 'test/unit'
require 'rack/test'
require 'pp'
require 'mocha'
require 'shoulda'
require 'json'

class TokenTest < Test::Unit::TestCase
  context Token do
    should "create a Token containing a UUID" do
      token = Token.new
      assert token.token =~ /^[A-F0-9\-]+$/i, "UUID does not match pattern: #{token.token}"
    end

    should "create a Token containing arbitrary JSON properties" do
      props = { "grant" => { "scope" => "unpaired", "token" => "ABCD" }}
      token = Token.new(:value => props)
      token.save
      new_token = Token.get(token.id)
      assert_equal props, new_token.value
    end
  end
end

class UserTest < Test::Unit::TestCase
  context User do
    setup do
      @user = User.create(:name => "dummy")
    end
    should "create a User containing an id" do
      assert @user.id, "User does not have an id"
    end

    should "create a User containing a name" do
      assert @user.name, "User does not have a name"
    end
  end
end

class AuthServerTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    AuthServer
  end

  def assert_status(status)
    assert_equal status, last_response.status
  end

  def assert_json_response_contains(key)
    begin
      text = last_response.body
      data = JSON.parse(text)
      assert data.key?(key)
    rescue => e
      fail "Not JSON response: '#{text}'"
    end
  end

  def assert_json_response_only_contains(key)
    begin
      text = last_response.body
      data = JSON.parse(text)
      assert data.key?(key)
      assert data.keys.length == 1
    rescue => e
      fail "Not JSON response: '#{text}'"
    end
  end

  context "A GET to /auth" do
    setup do
      # create a valid token
      post '/auth', :token => "VALID_TOKEN", :value => {"id" => 42}.to_json
    end

    should "return the contents of the passed in token" do
      get '/auth', :token => "VALID_TOKEN"
      assert_status 200
      data = JSON.parse(last_response.body)
      assert_equal({"id" => 42}, data['value'])
    end
  end

  context "A POST to /auth" do
    setup do
      post '/account', :id => 99, :name => "brian"
    end

    should "create a token when token parameter present" do
      post '/auth', :token => "BOB"
      assert_status 201
      assert_json_response_contains("token")
    end

    should "create a token when given a valid grant" do
      post '/auth', :grant => { :scope => "unpaired", :token => "ABCD" }
      assert_status 201
      assert_json_response_contains("token")
    end

    should "create a token when given a valid registration key and pin" do
      post '/assoc', :registration_key => "VALID_KEY", :id => 99
      assert_json_response_contains("pin")
      data = JSON.parse(last_response.body)

      post '/auth', :registration_key => "VALID_KEY", :pin => data["pin"]
      assert_status 201
      assert_json_response_only_contains("token")
    end

    should "not create a token when given an invalid registration key or pin" do
      post '/assoc', :registration_key => "KEY2", :id => 99
      assert_json_response_contains("pin")
      data = JSON.parse(last_response.body)

      post '/auth', :registration_key => "INVALID_KEY", :pin => data["pin"]
      assert_status 401
      assert last_response.body.empty?
    end
  end

  context "/authorized" do
    should "return 200 with correct token" do
      post '/auth', :token => 'AUTH'
      assert_status 201
      post '/authorized', :token => 'AUTH'
      assert_status 200
    end

    should "return JSON containing the token" do
      post '/auth', :token => 'AUTH'
      post '/authorized', :token => 'AUTH'
      assert_json_response_contains("token")
    end

    should "return 200 with another correct token" do
      post '/auth', :token => 'BOB'
      assert_status 201
      post '/authorized', :token => 'BOB'
      assert_status 200
    end

    should "return 200 with a correct grant" do
      post('/auth', :token => "ABCD", :value => { :scope => :can_register })
      post '/authorized', :grant => { :scope => 'can_register', :token => 'ABCD' }
      assert_status 200
    end

    should "return 401 with wrong token" do
      post '/auth', :token => 'AUTH'
      assert_status 201
      post '/authorized', :token => 'INVALID'
      assert_status 401
    end

    should "return 404 for GET requests" do
      get '/authorized'
      assert_status 404

      get '/authorized', :token => 'AUTH'
      assert_status 404
    end
  end

  context "/assoc" do
    context "a valid registration" do
      setup do
        post '/account', :id => 42, :name => "alice"
        post '/assoc', :registration_key => 'qwertz', :id => 42
      end

      teardown do
        delete '/account/42'
        if token = Token.first(:token => "qwertz")
          token.destroy
        end
      end

      context "associate an existing account with a registration key (i.e. device)" do
        should "return 201" do
          assert_status 201
        end

        should "return a PIN" do
          assert_json_response_contains "pin"
        end
      end

      # context "assoc should exist" do
      #   should "return 200 on get" do
      #     get "/assoc", :token => "qwertz"
      #     assert_status 200
      #   end
      # end

      context "can be deleted" do
        setup do
          delete "/assoc/qwertz"
        end

        should "return 204 on delete" do
          assert_status 204
        end

        should "return 404 on subsequent gets" do
          get "/assoc", :token => "qwertz"
          assert_status 404
        end
      end

    end

    context "an invalid registration" do
      context "when trying to associate a non-existent account with a registration key (i.e. device)" do
        setup do
          post '/assoc', :registration_key => 'qwerty', :id => 9999
        end

        should "return 401" do
          assert_status 401
        end
      end
    end

  end

  context "/account" do

    context "POST /account" do

      should "return 201" do
        post '/account', :id => 42, :name => "alice"
        assert_status 201
      end

      should "return id" do
        post '/account', :name => "alice"
        assert_json_response_contains "id"
        # check that id not nil
        text = last_response.body
        data = JSON.parse(text)
        assert data["id"]
        assert_status 201
      end

      should "return a JSON account object" do
        post '/account', :id => 43, :name => "alice"
        assert_json_response_contains "id"
        assert_json_response_contains "name"
      end

      should "return a 401 when trying to create an account with the same id as an existing one" do
        post '/account', :id => 40, :name => "alice"
        post '/account', :id => 40, :name => "bob"
        assert_status 401
      end
    end

    context "GET /account" do
      setup do
        post '/account', :id => 44, :name => "bob"
        get '/account/44'
      end

      should "return 200" do
        assert_status 200
      end

      should "return a JSON account object" do
        assert_json_response_contains "id"
        assert_json_response_contains "name"
      end
    end

    context "DELETE /account" do
      setup do
        post '/account', :id => 45, :name => "charlie"
        delete '/account/45'
      end

      should "return 200" do
        assert_status 200
      end

      should "return a JSON account object" do
        assert_json_response_contains "id"
        assert_json_response_contains "name"
      end
    end

  end

end
