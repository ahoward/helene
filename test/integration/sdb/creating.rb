testing Helene::Sdb::Base do

  context 'creating' do
    setup do
      @a = model(:a){}
    end

    should 'be able to create' do
      assert{ @a.create! }
    end
  end

end
