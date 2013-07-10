require 'bundler/capistrano'

set :application, "deployer"
set :repository, "git@github.com:ahmadeeva-su/deployer.git"
set :branch,  "master"

set :use_sudo, false

set :scm, :git
set :deploy_via, :remote_cache

set :user, "deployer"

set :public_ip, '176.9.24.2'

server "176.9.24.2", :web, :app, :background,
  :primary    => true,
  :private_ip => "176.9.24.2",
  :domain     => "deployer.alchemad.com",
  :unicorn    => {
    :port     => 8082,
    :workers  => 1
  }

set :deploy_to,    "/home/#{ user}/#{ application }"
set :unicorn_conf, "/#{ current_path }/config/unicorn.rb"
set :unicorn_pid,  "/#{ current_path }/tmp/unicorn.pid"

set :default_environment, {
  'PATH' => "/home/#{ user }/.rbenv/shims:/home/#{ user }/.rbenv/bin:$PATH"
}

set :rails_env, "production"

namespace :deploy do
  task :cold do
    update
  end

  task :start do
    run "cd #{ deploy_to }/current && bundle exec unicorn -c #{ unicorn_conf } -E #{ rails_env } -D"
  end

  task :restart do
    run "if [ -f #{ unicorn_pid } ]; then kill -USR2 `cat #{ unicorn_pid }`; else cd #{ deploy_to }/current && bundle exec unicorn -c #{ unicorn_conf } -E #{ rails_env } -D; fi"
  end

  task :stop do
    "if [ -f #{ unicorn_pid } ]; then kill -QUIT `cat #{ unicorn_pid }`; fi"
  end

  desc "Stop cron"
  task :stop_cron, :roles => :background do
    run "crontab -r || true"
  end

  namespace :configure do
    desc "Install cron jobs"
    task :cron, :roles => :background do
      template = ERB.new(
        File.read(File.expand_path("../deploy/templates/crontab.erb", __FILE__))
      )

      config = template.result(binding)

      put(config, "#{ shared_path }/crontab.conf")

      run "crontab #{ shared_path }/crontab.conf"
    end

    desc "Updates nginx configuration for balancer"
    task :nginx, :roles => :balancer do
      template = ERB.new(
        File.read(File.expand_path("../deploy/templates/nginx.conf.erb", __FILE__))
      )

      app_servers = top.find_servers(:roles => :app)

      find_servers_for_task(current_task).each do |server|
        config = template.result(binding)

        put(config, "#{ shared_path }/nginx.conf")
      end
    end

    task :restart_nginx_instructions do
      puts %{
        Under root user, copy config files and restart services:

        cp #{ shared_path }/nginx.conf /opt/nginx/conf/sites/#{ application }_balancer.conf

        restart nginx
      }
    end
  end
end

before "deploy:update_code", "deploy:stop_cron"
after  "deploy",             "deploy:configure:cron"
after  "deploy",             "deploy:configure:nginx"
after  "deploy",             "deploy:configure:restart_nginx_instructions"