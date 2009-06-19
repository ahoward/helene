module Helene
  module S3
    class Owner
      attr_reader :id, :name
      
      def initialize(id, name)
        @id   = id
        @name = name
      end
      
      def to_s
        @name
      end
    end
  end
end
