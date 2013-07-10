require 'yaml'
require 'json'

class Director < Sinatra::Base
  use Rack::Auth::Basic, "Restricted Area" do |username, password|
    username == 'admin' and password == 'd3@d60a_214'
  end

  get '/' do
    @deploy_data = YAML::load_file(settings.data_file).tap do |data|
      data['head_commit']['time'] = Time.parse data['head_commit']['time']
      data['deploy']['time']      = Time.parse data['deploy']['time']
      data['deploy']['log'].prepend('<br /><br />').gsub!(/\r?\n/, '<br />')
    end

    @flags = {
      'restore' => File.exist?("#{ settings.shared_path }/restore.flag"),
      'deploy'  => File.exist?("#{ settings.shared_path }/deploy.flag")
    }

    erb :index
  end


  get '/hook' do
    @push_data = JSON.parse params[:payload]

    if @push_data['ref'] == 'refs/heads/master'
      if @push_data['commits'].collect{ |c| c['modified'] }.flatten.include?('db/schema.rb')
        set_migrate_flag
      end

      set_deploy_flag

      store_push_data
    end

    'OK'
  end


  post '/restore' do
    set_restore_flag

    'OK'
  end


  post '/deploy' do
    set_deploy_flag

    'OK'
  end


  def set_restore_flag
    `echo 1 > #{ settings.shared_path }/restore.flag`
  end

  def set_migrate_flag
    `echo 1 > #{ settings.shared_path }/migrate.flag`
  end

  def set_deploy_flag
    `echo 1 > #{ settings.shared_path }/deploy.flag`
  end

  def store_push_data
    deploy_data = (YAML::load_file(settings.data_file) || {}).tap do |data|
      data['head_commit'] = {
        'id'       => @push_data['head_commit']['id'],
        'message'  => @push_data['head_commit']['message'],
        'url'      => @push_data['head_commit']['url'],
        'time'     => @push_data['head_commit']['timestamp'],
        'deployed' => false
      }
    end

    File.write(settings.data_file, deploy_data.to_yaml)
  end
end