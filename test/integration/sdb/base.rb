testing Helene::Sdb::Base do

  context 'creating' do
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


  context 'associations' do
    class A < Helene::Sdb::Base
      one_to_many :bs
    end

    class B < Helene::Sdb::Base
      #many_to_one :as
    end

    class C < Helene::Sdb::Base
    end

    setup do
    end

    should 'do basic one_to_many' do
      assert true  
    end

    should 'do basic many_to_one' do
      assert true  
    end
  end

end
