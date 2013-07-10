namespace :app do
  desc "Deploy project on staging if needed"
  task :deployment do
    next unless File.exist?("#{ settings.shared_path }/deploy.flag")

    restore = File.exist?("#{ settings.shared_path }/restore.flag")
    migrate = File.exist?("#{ settings.shared_path }/migrate.flag")

    puts "\nDeployment: restore=#{ restore }, migrate=#{ migrate }"

    if restore
      puts "Restoring database form backup..."

      `cd #{ settings.deploy_path }; RAILS_ENV=#{ settings.deploy_env } bundle exec rake db:drop db:create db:schema:load`
    
      `mysql --user=#{ settings.db['username'] } --password=#{ settings.db['password'].to_s } #{ settings.db['database'] } < #{ settings.mysql_backup }`

      puts "Restoring Redis..."

      `cd #{ settings.deploy_path }; bundle exec rake app:redis:restore[#{ settings.redis_backup }]`
    end


    # deploy
    puts "Deploying #{ 'with_migration' if migrate || restore }... (#{ Time.now.strftime('%Y.%m.%d %H:%M') })"

    puts `cd #{ settings.deploy_path }; git pull origin master`

    log = if migrate || restore
      `cd #{ settings.deploy_path }; git status` # `cd #{ settings.deploy_path }; cap staging deploy:migrations`
    else
      `cd #{ settings.deploy_path }; git status` # `cd #{ settings.deploy_path }; cap staging deploy`
    end

    File.delete("#{ settings.shared_path }/restore.flag") if restore
    File.delete("#{ settings.shared_path }/migrate.flag") if migrate
    File.delete("#{ settings.shared_path }/deploy.flag")


    # store results
    deploy_data = YAML::load_file(settings.data_file).tap do |data|
      data['deploy'] = {
        'time' => Time.now.xmlschema,
        'log'  => log
      }
      data['head_commit']['deployed'] = true
    end

    File.write(settings.data_file, deploy_data.to_yaml)

    puts "Done!\n\n"
  end
end