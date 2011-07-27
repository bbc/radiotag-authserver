require 'dm-types'
require 'generate_id'

class Token
  include DataMapper::Resource

  property :id, Serial
  property :token, String, :default => lambda {|r, p| GenerateID.uuid }
  property :value, Json
end
