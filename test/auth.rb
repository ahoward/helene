# TODO - needs to bootstrap from a test config file - for now rely on
#
# ENV['AWS_ACCESS_KEY_ID']
# ENV['AWS_SECRET_ACCESS_KEY']
#

config = YAML.load((File.read(File.expand_path("~/.aws.yml")) rescue "{}"))

if access_key_id = config["access_key_id"]
  ENV['ACCESS_KEY_ID']            = access_key_id
  ENV['AMAZON_ACCESS_KEY_ID']     = access_key_id
  ACCESS_KEY_ID                   = access_key_id
  AMAZON_ACCESS_KEY_ID            = access_key_id
end

if secret_access_key = config["secret_access_key"]
  ENV['SECRET_ACCESS_KEY']        = secret_access_key
  ENV['AMAZON_SECRET_ACCESS_KEY'] = secret_access_key
  ACCESS_SECRET_KEY               = secret_access_key
  AMAZON_SECRET_ACCESS_KEY        = secret_access_key
end

if ca_file = config["ca_file"]
  ENV['CA_FILE']        = ca_file
  ENV['AMAZON_CA_FILE'] = ca_file
  CA_FILE               = ca_file
  AMAZON_CA_FILE        = ca_file
  
  # It's too late to count on helene.rb to load this, so we need to do it:
  Rightscale::HttpConnection.params[:ca_file] = ca_file
end
