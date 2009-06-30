testing Helene::Sdb::Base do

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
        assert @a.count >= n
      end
    end
  end

end
