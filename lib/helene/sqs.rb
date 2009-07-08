module Helene
  module Sqs
    load "helene/sqs/queue.rb"
    
    Interface = RightAws::SqsGen2Interface
    extend Connectable
  end
end
