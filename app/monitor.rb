class Monitor
  attr_reader :uuid       # Worker UUID
  attr_reader :status     # Process status
  attr_reader :pid        # Process ID
  attr_reader :services   # List of monitored services
  
  # Initialize a new Monitor instance
  #
  # server - Server instance
  #
  def initialize(server)
    unless server.kind_of?(Server)
      raise ArgumentError, "Server required."
    end
    
    @uuid     = UUIDTools::UUID.random_create.to_s
    @server   = server
    @node     = @server.node
    @pid      = nil
    @status   = 'stopped'
    @services = []
  end
  
  # Returns true if the monitor is running
  #
  def running?
    !pid.nil? && status == 'running'
  end
  
  # Start monitor process
  #
  def start(services=[])
    raise RuntimeError, "Already running" if running?
    raise RuntimeError, "No services defined" if services.empty?
    
    @status = 'running'
    @pid = fork do
      storage = Redis.new
      loop do
        trap 'TERM' do
          storage.hdel('munin_monitor', @server.name)
          @status = 'stopped'
          Process.exit!
        end
        data = @node.fetch(services)
        storage.hset('munin_monitor', @server.name, data.to_json)
        sleep(1)
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
    {'uuid' => @uuid, 'status' => @status}
  end
end