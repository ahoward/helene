testing Helene::Sdb::Base do

# TODO - split this out into individual files...

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
      assert{ @a.new.save }
      assert{ @b.new(:foo=>'foo').save }
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

    perform = 'be able to find by id'
    should perform do
      a = assert{ @a.create! }
      eventually_assert(perform) do
        found = @a.find(a.id)
        found and found.id == a.id
      end
    end

    perform = 'be able to find by many ids'
    should perform do
      a = assert{ @a.create! }
      eventually_assert(perform) do
        list = @a.find([a.id, a.id])
        list.all?{|found| found.id==a.id}
      end
    end

    perform = 'be able to find by > 20 ids'
    should perform do
      a = assert{ @a.create! }
      ids = Array.new(42){ a.id }
      eventually_assert(perform) do
        list = assert{ @a.find(ids) }
        list and list.all?{|found| found.id == a.id}
      end
    end
  end

  context 'limit > 2500' do
    setup do
      @a = model(:a)
    end

    perform = 'get all the results'
    should perform do
      n = 2501
      assert_nothing_raised do
        if @a.count < n
          records = Array.new(n){ @a.new }
          a = Time.now.to_f
          @a.batch_put records
          b = Time.now.to_f
          #puts(b - a)
        end
      end
      eventually_assert(perform) do
        result = @a.find(:all, :limit => n)
        assert result.size == n
      end
    end
  end

  context 'emptiness' do
    setup do
      @a = model(:a) do
        attribute :x, :string
        attribute :y, :set_of_string
      end
    end

    perform = 'represent nil'
    should perform do
      a = assert{ @a.create! :x => nil }
      assert{ a.x.nil? }
      eventually_assert(perform){ a.reload; a.x.nil? }
    end

    perform = 'represent the empty list'
    should perform do
      a = assert{ @a.create! :y => [] }
      assert{ a.y==[] }
      eventually_assert(perform){ a.reload; a.y==[] }
    end

    perform = 'represent a list of just nil'
    should perform do
      a = assert{ @a.create! :y => [nil] }
      assert{ a.y==[nil] }
      eventually_assert(perform){ a.reload; a.y==[nil] }
    end

    perform = 'represent the empty string'
    should perform do
      a = assert{ @a.create! :x => '' }
      assert{ a.x=='' }
      eventually_assert(perform){ a.reload; a.x=='' }
    end

    perform = 'represent a list of just the empty string'
    should perform do
      a = assert{ @a.create! :y => [''] }
      assert{ a.y==[''] }
      eventually_assert(perform){ a.reload; a.y==[''] }
    end

=begin
    perform = 'represent a list nil and the empty string'
    should perform do
      a = assert{ @a.create! :y => [nil, ''] }
      assert{ a.y==[nil, ''] }
      eventually_assert(perform){ a.reload; a.y==[nil, ''] }
    end
=end
  end

  context 'types' do
    setup do
      @a = model(:a) do
        attribute :x, :text
      end
    end

    perform = 'be able to represent text fields > 1024'
    should perform do
      text = '*' * ((1024 * 9) + 3)
      a = assert{ @a.create! :x => text }
      assert{ a.x==text }
      eventually_assert(perform){ a.reload; a.x==text }

      text = 'abc' + text + 'xyz'
      a = assert{ @a.create! :x => text }
      assert{ a.x==text }
      assert{ a.x.first(3)=='abc' }
      assert{ a.x.last(3)=='xyz' }
      eventually_assert(perform){
        a.reload;
        a.x==text
        a.x.first(3)=='abc'
        a.x.last(3)=='xyz'
      }
    end
  end

  context 'hooks' do
    setup do
      @a = model(:a) do
        attribute :x, :string
        before_save{ update :x => '42' }
      end
    end

    perform = 'before_save'
    should perform do
      a = assert{ @a.create! }
      assert{ a.x=='42' }
      eventually_assert(perform){ a.reload; a.x=='42' }
    end
  end


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
