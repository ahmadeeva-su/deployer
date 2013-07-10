workers     = 1
host        = "176.9.24.2"
port        = 8082
app_folder  = File.expand_path('../..', __FILE__)

pid File.join(app_folder, "tmp/unicorn.pid")

working_directory app_folder

worker_processes workers

# make forks faster
preload_app true

# Restart any workers that haven't responded in 30 seconds
timeout 60

listen "#{ host }:#{ port }", :backlog => workers * 20

stderr_path File.join(app_folder, "log/unicorn.log")
stdout_path File.join(app_folder, "log/unicorn.log")

before_exec do |_|
  ENV["BUNDLE_GEMFILE"] = File.join(app_folder, "Gemfile")
end

before_fork do |server, worker|
  ##
  # When sent a USR2, Unicorn will suffix its pidfile with .oldbin and
  # immediately start loading up a new version of itself (loaded with a new
  # version of our app). When this new Unicorn is completely loaded
  # it will begin spawning workers. The first worker spawned will check to
  # see if an .oldbin pidfile exists. If so, this means we've just booted up
  # a new Unicorn and need to tell the old one that it can now die. To do so
  # we send it a QUIT.
  #
  # Using this method we get 0 downtime deploys.

  old_pid = File.join(app_folder, "tmp/unicorn.pid.oldbin")

  if File.exists?(old_pid) && server.pid != old_pid
    begin
      Process.kill("QUIT", File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
      # someone else did our job for us
    end
  end
end


after_fork do |server, worker|
  GC.disable

  $unicorn_worker = worker.nr
end