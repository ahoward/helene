module Helene
  class Error < ::StandardError; end
  class WTF < Error; end

  def Helene.error!(*args, &block)
    raise Error.new(*args, &block)
  end

  def Helene.wtf!(*args, &block)
    raise WTF.new(*args, &block)
  end
end
