module Helene
  #
  # = Synopsys
  # 
  # First you need to build a Queue (or Q).  You just create an instance of it
  # by name.  That's all you have to do if the Queue already exists as the code
  # will lookup the URL for it (what Amazon recommends).  If it doesn't exist
  # yet, you need to add a call to create().  There's no harm to recreating a
  # Queue that already exists, so it's fine just to call that to be safe
  # whenever your code loads:
  # 
  #   q = Helene::Sqs::Q.new("aras_test_q")
  #   q.create  # optional after the first time
  # 
  # You can pass a default message visibility timeout for the queue in seconds
  # to create() if you want, or set it later:
  # 
  #   q.update_visibility_timeout(120)
  # 
  # Deleting a Queue is just:
  # 
  #   q.delete
  # 
  # The main stuff is sending and receiving Messages, of course.  That's simple:
  # 
  #   q.q("Test Message")  # or queue(), or send_message(), ...
  #   # ...
  #   mes = q.dq  # or dequeue() or receive_message()
  # 
  # If you want to see receive up to ten messages at a time (Amazon's limit),
  # you can use receive_messages():
  # 
  #   ary_of_mes = q.receive_messages
  # 
  # You can pass visibility timeouts for this set of messages to either fetch
  # method.
  # 
  # A Message can check it's own validity (Amazon sends down an MD5 with it):
  # 
  #   mes.valid?
  # 
  # You can also read the raw content from it:
  # 
  #   content = mes.body
  # 
  # When you are finished with a Message, you can remove it from the Queue:
  # 
  #   mes.delete  # or remove() or destroy()
  # 
  module Sqs
    load "helene/sqs/message.rb"
    load "helene/sqs/queue.rb"
    
    extend Connectable
  end
end
