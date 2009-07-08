module Helene
  module Sdb
    load 'helene/sdb/error.rb'
    load 'helene/sdb/sentinel.rb'
    load 'helene/sdb/interface.rb'
    load 'helene/sdb/base.rb'

    extend Connectable
  end
end
