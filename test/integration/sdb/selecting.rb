testing Helene::Sdb::Base do

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
      #eventually_assert(perform) do
        list = assert{ @a.find(ids) }
        list and list.all?{|found| found.id == a.id}
      #end
    end
  end

end
