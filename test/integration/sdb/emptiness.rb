testing Helene::Sdb::Base do

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

end
