DataMapper.setup :default, 'sqlite:export.db'

class Unit
  include DataMapper::Resource
  
  property :id, Serial
  property :evalweb_id, String
  property :address, String
  property :value, Integer
  property :previous_value, Integer
  
  belongs_to :usage
  
  has n, :owners, through: Resource
end

class Owner
  include DataMapper::Resource
  
  property :id, Serial
  property :name, String
  
  has n, :units, through: Resource
end

class Usage
  include DataMapper::Resource
  
  property :id, Serial
  property :name, String
  
  has n, :units
end

DataMapper.finalize