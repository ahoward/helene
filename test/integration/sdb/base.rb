testing Helene::Sdb::Base do

  context 'creating' do
    class A < Helene::Sdb::Base
    end

    should 'be able to create' do
      assert{ A.create! }
    end
  end


  context 'saving' do
    class A < Helene::Sdb::Base
    end
    class B < Helene::Sdb::Base
      attribute :foo, :null => false
    end

    should 'be able to save a valid object' do
      assert{ A.new.save == true }
      assert{ B.new(:foo=>'foo').save == true }
    end

    should 'not be able to save an invalid object' do
      assert{ B.new(:foo=>nil).save == false }
    end
  end


  context 'selecting' do
    class A < Helene::Sdb::Base
    end
    class B < Helene::Sdb::Base
    end
    class C < Helene::Sdb::Base
    end

    should 'be able to find by id' do
      a = assert{ A.create! }
      eventually_assert('find by id') do
        found = A.find(a.id)
        found and found.id == a.id
      end
    end

    should 'be able to find by many ids' do
      a = assert{ A.create! }
      eventually_assert('find by id') do
        list = A.find([a.id, a.id])
        list.all?{|found| found.id==a.id}
      end
    end

    should 'be able to find by > 20 ids (using threadify)' do
      a = assert{ A.create! }
      ids = Array.new(42){ a.id }
      eventually_assert('find by > 20 ids') do
        list = assert{ A.find(ids) }
        #list = ids.threadify(:each_slice, 20){|slice| A.find(slice) }.flatten
        list and list.all?{|found| found.id == a.id}
      end
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
