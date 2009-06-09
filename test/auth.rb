# TODO - needs to bootstrap from a test config file - for now rely on
#
# ENV['AWS_ACCESS_KEY_ID']
# ENV['AWS_SECRET_ACCESS_KEY']
#
  Helene.aws_access_key_id     # raises error unless configured
  Helene.aws_secret_access_key # raises error unless configured
