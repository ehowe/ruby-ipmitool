require 'ipmitool'
ipmi = Ipmitool.new(:host => '192.168.3.158', :user => 'ADMIN', :password => 'ADMIN')
#puts ipmi.sensor.system_temp
#puts ipmi.sensor.inspect
#puts ipmi.chassis("power", "on").chassis_power_control
#puts ipmi.chassis("policy", "list").inspect
#puts ipmi.chassis("restart_cause").system_restart_cause
#puts ipmi.chassis("poh").poh_counter
#puts ipmi.chassis("bootdev","pxe").result
#puts ipmi.chassis("selftest").self_test_results
#puts ipmi.sdr.fan10
#puts ipmi.channel("getciphers", "ipmi", "1").inspect
#puts ipmi.channel("authcap", "1", "4").ipmi_v15_auth_types
#puts ipmi.channel("getaccess", "1", "2").privilege_level
puts ipmi.user("list", "1").uid2
#puts ipmi.channel("setaccess", "1", "3", "3").inspect
#puts ipmi.channel("getciphers", "ipmi", "1").inspect
#puts ipmi.sel.inspect
