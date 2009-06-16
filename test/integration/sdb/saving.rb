testing Helene::Sdb::Base do

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

end
