module Kernel
  private
    def this_method_name
      caller[0] =~ /`([^']*)'/ && $1
    end
end
  
class Hash
  def method_missing(name, *args, &blk)
    if self.keys.map(&:to_sym).include? name.to_sym
      return self[name.to_sym]
    else
      super
    end
  end
end


=begin rdoc
This utility wraps the UNIX ipmitool command to provide common functions

All methods in this class return a hash, which can be read as accessors.

For more information on the output and its meanings, see the official ipmitool man page at http://ipmitool.sourceforge.net/manpage.html
=end

class Ipmitool
    attr_reader :conn

  #Instantiates a new Ipmitool object.  Takes a hash containing :host, :user, and :password.
  #
  #Ex: Ipmitool.new(:host => '192.168.1.1', :user => 'username', :password => 'password', :optional => {})
  def initialize(conn = {})
    conn[:check_host] ||= true
    raise ArgumentError, "Wrong number of arguments" if conn.count < 4
    raise ArgumentError, "Host is required" if conn[:host].nil?
    raise ArgumentError, "User is required" if conn[:user].nil?
    raise ArgumentError, "Password is required" if conn[:password].nil?
    @conn = conn
    @conn[:binary] = `which ipmitool`.chomp
    binary = system('which ipmitool > /dev/null')
    raise ArgumentError, "Missing ipmitool" unless binary
    if conn[:check_host]
      raise ArgumentError, "Host is down or invalid!" unless check_host
    end
  end

  #Run a ping check to see if the host is responding
  def check_host
    result = `ping -q -c 2 #{@conn[:host]}`
     # return true or false if exit status is 0
    $?.exitstatus == 0
  end

  #Read sensor data from ipmitool and return a hash containing the value
  #
  #Returned format is {:sensor_name => ['value1', 'value2']}
  #Ex. Ipmitool.new(:host => '192.168.1.1', :user => 'username', :password => 'password').sensor.fan1
  def sensor
    sensor_output = run_command(this_method_name).split("\n")
    sensor_hash = split_output(sensor_output, '|')
    return sensor_hash = sensor_hash.each { |k,v| sensor_hash[k.to_sym] = v.split(/\s\|\s/) }
  end

  #Same as sensor, but the output is a bit more formatted for everyday use
  def sdr
    sdr_output = run_command(this_method_name).split("\n")
    sdr_hash = split_output(sdr_output, '|')
    return sdr_hash = sdr_hash.each { |k,v| sdr_hash[k.to_sym] = v.split(/\s\|\s/) }
  end

  #Query and issue commands to the chassis itself.  Useful for powering a box on and off, resets, etc
  #
  #Ex ipmi.chassis("power", "on").chassis_power_control
  def chassis(chassis_command, *command_args)
    chassis_hash = Hash.new
    case chassis_command
    when "status", "restart_cause", "poh", "selftest"
      chassis_output = run_command(this_method_name, chassis_command)
      chassis_output = chassis_output.split("\n")
      chassis_hash = split_output(chassis_output, ':')
    when "power"
      raise ArgumentError, "#{chassis_command} requires an additional argument" if command_args.empty?
      chassis_output = run_command(this_method_name, "#{chassis_command} #{command_args}")
      chassis_hash = split_output(chassis_output.to_a, ":")
      return chassis_hash
    when "policy"
      raise ArgumentError, "Policy requires a state" if command_args.empty?
      if command_args.to_s == 'list'
        chassis_output = run_command(this_method_name, "#{chassis_command} #{command_args}")
        chassis_hash = split_output(chassis_output.split("\n"), ":")
      else
        chassis_hash[:result] = run_command(this_method_name, "#{chassis_command} #{command_args}").gsub("\n","")
        return chassis_hash
      end
    when "bootdev"
        raise ArgumentError, "bootdev requires an additional argument" if command_args.empty?
        chassis_hash[:result] = run_command(this_method_name, "#{chassis_command} #{command_args}").gsub("\n","")
        return chassis_hash
    else
      raise ArgumentError, "Invalid Chassis Command"
    end
  end

  #Shortcut to ipmi.chassis("power").  Values returned are formatted exactly as ipmi.chassis.
  #
  #Ex. ipmi.power("on")
  def power(power_command)
    return chassis("power", power_command)
  end

  #Set channel options, including authentication.  For options that require more than 1 option, that should be specified as separate options to the method.
  #
  #Ex. ipmi.channel("getciphers", "ipmi", "1").inspect
  #
  #The setaccess function gives no output
  def channel(channel_command, *command_args)
    channel_hash = Hash.new
    case channel_command
    when "authcap"
      raise ArgumentError, "Authcap requires a channel number and privilege" if command_args.empty?
      channel_output = run_command(this_method_name, "#{channel_command} #{command_args.join(' ')}")
      return channel_hash = split_output(channel_output, ':')
    when "getaccess"
      raise ArgumentError, "Authcap requires a channel number and uid" if command_args.empty?
      user_hash = user("list", command_args[0])
      raise ArgumentError, "Invalid user specified" unless user_hash.has_key?("uid#{command_args[1]}".to_sym)
      channel_output = run_command(this_method_name, "#{channel_command} #{command_args.join(' ')}")
      channel_hash = split_output(channel_output, ':')
    when "setaccess"
      raise ArgumentError, "Authcap requires a channel number, uid, and privilege level" if command_args.empty?
      user_hash = user("list", command_args[0])
      raise ArgumentError, "Invalid user specified" unless user_hash.has_key?("uid#{command_args[1]}".to_sym)
      command_args[2] = "privilege=#{command_args[2]}"
      run_command(this_method_name, "#{channel_command} #{command_args.join(' ')}")
    when "info"
      raise ArgumentError, "Info requires a channel number" if command_args.empty?
      channel_output = run_command(this_method_name, "#{channel_command} #{command_args}")
      channel_output = channel_output.grep(/:/).each { |line| line.strip! }.delete_if { |line| line =~ /:$/ }
      return channel_hash = split_output(channel_output, ':')
    when "getciphers"
       raise ArgumentError, "Info requires a protocol and channel number" if command_args.empty?
       channel_output = run_command(this_method_name, "#{channel_command} #{command_args.join(' ')}").grep(/^[0-9]/)
       channel_output.each { |c| channel_hash["id#{c.split[0]}".to_sym] = c.split[1..-1] }
       return channel_hash
    else
      raise ArgumentError, "Invalid Channel Command"
    end
  end

  #Add and modify users.
  #
  #set name, set password, disable, enable, and priv do not give output
  def user(user_command, *command_args)
    user_hash = Hash.new
    case user_command
    when "list"
      raise ArgumentError, "List requires a channel number" if command_args.empty?
      user_output = run_command(this_method_name, "#{user_command} #{command_args}").grep(/^[0-9]/)
      user_output.each { |u| user_hash["uid#{u.split[0]}".to_sym] = u.split[1..-1] }
      return user_hash
    when "set name", "set password", "priv"
      raise ArgumentError, "#{user_command} requires 2 arguments" if command_args.empty?
      run_command(this_method_name, "#{user_command} #{command_args.join(' ')}")
    when "disable", "enable"
      raise ArgumentError, "#{user_command} requires a UID" if command_args.empty?
      run_command(this_method_name, "#{user_command} #{command_args}")
    else
      raise ArgumentError, "Invalid User Command"
    end
  end

  #This function takes no arguments and returns logging output
  def sel
    sel_output = run_command(this_method_name).split("\n").grep(/:/)
    return sel_hash = split_output(sel_output, ':')
  end

  private
  def run_command(command, *args)
    $optional=''
    if @conn.optional
        @conn.optional.each { |key, value|
            $optional << "-#{key} #{value}"
        }
    end
            
    `#{@conn[:binary]} #{$optional} -H #{@conn[:host]} -U #{@conn[:user]} -P #{@conn[:password]} #{command} #{args unless args.nil?}`
  end

  def split_output(array, delimiter)
    split_hash = Hash.new
    delimiter = "\\#{delimiter}"
    array.each { |stat| split_hash[stat.split(/\s*#{delimiter}\s?/)[0].gsub(/\s+/," ").gsub(' ','_').gsub('.','').gsub(/^#/,"number").to_sym] = stat.split(/\s*#{delimiter}\s?/,2)[1].strip }
    return split_hash
  end
end
