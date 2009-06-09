testing Helene::Sdb::Base do


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
