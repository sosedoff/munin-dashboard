class Server
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :name
  field :description
  field :host
  field :port,     :type => Integer, :default => 4949
  field :enabled,  :type => Boolean, :default => false
  field :services, :type => Array,   :default => []
  field :version
  
  validates :name, :presence   => true,
                   :uniqueness => true,
                   :length     => {:within => 2..32},
                   :format     => {:with => /^[a-z\d\-\_]{2,32}$/i}
                   
  validates :host, :presence   => true,
                   :uniqueness => true,
                   :format     => {:with => /^[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}$/}
                   
  validates :port, :presence => true, :numericality => true
  
  before_create :check_connection
  
  # Get munin node connection
  #
  def node
    @node ||= Munin::Node.new(self.host, self.port)
  end
  
  # Discover all services on the node
  #
  def services
    node.list
  end
  
  # JSON Representation
  #
  def as_json(options={})
    {
      'name'     => self.name,
      'host'     => self.host,
      'port'     => self.port,
      'enabled'  => self.enabled,
      'services' => self.services,
      'version'  => self.version
    }
  end
  
  def self.find_by_name(name)
    Server.where(:name => name).first
  end
  
  private
  
  def check_connection
    begin
      node.connect
      self.version  = node.version
      self.services = node.list
    rescue Munin::ConnectionError, Munin::AccessDenied, Munin::InvalidResponse => ex
      errors.add(:host, ex.message)
    end
  end
end