class Monitor
  KEY_CONFIG = 'munin_config'
  KEY_FETCH  = 'munin_fetch'
  
  attr_reader :uuid       # Worker UUID
  attr_reader :status     # Process status
  attr_reader :pid        # Process ID
  attr_reader :services   # List of monitored services
  attr_reader :period     # Update frequency (seconds)
  
  # Initialize a new Monitor instance
  #
  # server - Server instance
  #
  def initialize(server, services, period=3)
    unless server.kind_of?(Server)
      raise ArgumentError, "Server required."
    end
    
    @uuid     = UUIDTools::UUID.random_create.to_s
    @server   = server
    @node     = @server.node
    @pid      = nil
    @status   = 'stopped'
    @services = services
    @period   = period
  end
  
  # Returns true if the monitor is running
  #
  def running?
    !pid.nil? && status == 'running'
  end
  
  # Start monitor process
  #
  def start
    raise RuntimeError, "Already running" if running?
    raise RuntimeError, "No services defined" if services.empty?
    
    @status = 'running'
    @pid = fork do
      storage = Redis.new
      
      # Store current configuration
      storage.hset(
        KEY_CONFIG,
        @server.name,
        @node.config(services)
      )
      
      loop do
        trap 'TERM' do
          # Cleanup redis keys
          storage.hdel(KEY_CONFIG, @server.name)
          storage.hdel(KEY_FETCH, @server.name)
          
          @status = 'stopped'
          Process.exit!
        end
        data = @node.fetch(services)
        storage.hset(KEY_FETCH, @server.name, data.to_json)
        sleep(@period)
      end
    end
    Process.detach(@pid)
    @pid
  end
  
  # Stop monitor process
  #
  def stop
    if running?
      begin
        Process.kill('TERM', pid)
      rescue Errno::ESRCH
        warn "Process with pid #{pid} does not exist."
      end
      @pid    = nil
      @status = 'stoppped'
    end
  end
  
  def as_json(options={})
    {
      'uuid'     => uuid,
      'services' => services,
      'period'   => period,
      'status'   => status
    }
  end
end