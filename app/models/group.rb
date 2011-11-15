class Group
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :name
    
  validates :name, :presence   => true,
                   :uniqueness => true,
                   :length     => {:within => 2..64}
end
