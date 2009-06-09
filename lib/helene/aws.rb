module Helene
  class << Helene
    def aws_access_key_id(*value)
      self.aws_access_key_id = value.first unless value.empty?

      @aws_access_key_id ||= (
        candidates = %w[ AWS_ACCESS_KEY_ID AMAZON_ACCESS_KEY_ID ACCESS_KEY_ID ]
        candidates.each do |candidate|
          return Object.const_get(candidate) if Object.const_defined?(candidate)
        end
        candidates.each do |candidate|
          return ENV[candidate] if ENV[candidate]
        end
        raise Error, 'no configured aws_access_key_id'
      )
    end
    attr_writer :aws_access_key_id

    def aws_secret_access_key(*value)
      self.aws_secret_access_key = value.first unless value.empty?

      @aws_secret_access_key ||= (
        candidates = %w[ AWS_SECRET_ACCESS_KEY AMAZON_SECRET_ACCESS_KEY SECRET_ACCESS_KEY ]
        candidates.each do |candidate|
          return Object.const_get(candidate) if Object.const_defined?(candidate)
        end
        candidates.each do |candidate|
          return ENV[candidate] if ENV[candidate]
        end
        raise Error, 'no configured aws_secret_access_key'
      )
    end
    attr_writer :aws_secret_access_key
  end
end
