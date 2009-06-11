testing Helene::Sdb::Base do

  context 'creating' do
    setup do
      @a = model(:a){}
    end

    should 'be able to create' do
      assert{ @a.create! }
    end
  end


  context 'saving' do
    setup do
      @a = model(:a)
      @b = model(:b) do
        attribute :foo, :null => false
      end
    end

    should 'be able to save a valid object' do
      assert{ @a.new.save == true }
      assert{ @b.new(:foo=>'foo').save == true }
    end

    should 'not be able to save an invalid object' do
      assert{ @b.new(:foo=>nil).save == false }
    end
  end

  context 'selecting' do
    setup do
      @a = model(:a)
      @b = model(:b)
      @c = model(:c)
    end

    should 'be able to find by id' do
      a = assert{ @a.create! }
      eventually_assert('find by id') do
        found = @a.find(a.id)
        found and found.id == a.id
      end
    end

    should 'be able to find by many ids' do
      a = assert{ @a.create! }
      eventually_assert('find by id') do
        list = @a.find([a.id, a.id])
        list.all?{|found| found.id==a.id}
      end
    end

=begin
    should 'be able to find by > 20 ids (using threadify)' do
      a = assert{ @a.create! }
      ids = Array.new(42){ a.id }
      eventually_assert('find by > 20 ids') do
        list = assert{ @a.find(ids) }
        list and list.all?{|found| found.id == a.id}
      end
    end
=end
  end
=begin

  context 'magic fields' do
    
  end
=end

=begin
  context 'limit > 2500' do
    setup do
      @a = model(:a)
    end

    should 'get all the results' do
      n = 2501
      assert_nothing_raised do
        Array.new(n).threadify{ @a.create }
      end
      sleep 3
      #eventually_assert do
        result = @a.find(:all, :limit => n)
        assert result.size == n
      #end
    end
  end
=end


=begin
  context 'associations' do
    context 'one_to_many' do
      class A < Helene::Sdb::Base
        one_to_many :bs
      end

      class B < Helene::Sdb::Base
        attribute :a_id
      end

      setup do
      end

      should 'support simple one_to_many' do
        a = assert{ A.create! }
        assert{ a.respond_to?(:bs) }
        b = assert{ B.create! }
        #assert{ a.respond_to?(:a_id) }
        #assert{ a.bs << b }
        p a.bs
      end

    end
  end
=end

end
