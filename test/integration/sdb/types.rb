testing Helene::Sdb::Base do

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

end
