module Helene
  module Sqs
    load "helene/sqs/message.rb"
    load "helene/sqs/queue.rb"
    
    extend Connectable
  end
end
