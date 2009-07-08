testing Helene::Sdb::Base do
  context 'equality' do
    setup do
      @a = model(:a)
    end

    should 'compare identical objects as equal' do
      a = @a.create!
      assert(a==a) 
    end

    should 'not compare different objects as equal' do
      a = @a.create!
      b = @a.create!
      assert(a!=b) 
    end

    should 'not compare equally to only object from the same domain' do
      10.times{ @a.create! }
      list = @a.all(:limit => 10)
      first = list.first
      assert(list.select{|element| element==first}.size==1)
    end
  end
end
