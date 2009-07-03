testing Helene::Sdb::Base do

  context 'types' do
    setup do
      @a = model(:a) do
        attribute :text, :text
        attribute :keyval, :keyval
      end
    end

    perform = 'be able to represent text fields > 1024'
    should perform do
      text = '*' * ((1024 * 9) + 3)
      a = assert{ @a.create! :text => text }
      assert{ a.text==text }
      eventually_assert(perform){ a.reload; a.text==text }

      text = 'abc' + text + 'xyz'
      a = assert{ @a.create! :text => text }
      assert{ a.text==text }
      assert{ a.text.first(3)=='abc' }
      assert{ a.text.last(3)=='xyz' }
      eventually_assert(perform){
        a.reload;
        a.text==text
        a.text.first(3)=='abc'
        a.text.last(3)=='xyz'
      }
    end

    perform = 'be able to store keyval pairs'
    should perform do
      keyval = {'a' => 'foo', 'b' => 'bar'}
      a = assert{ @a.create! :keyval => keyval }
      assert{ a.keyval.keys.sort==keyval.keys.sort }
      assert{ a.keyval.values.sort==keyval.values.sort }
      eventually_assert(perform){ a.reload; a.keyval==keyval }

      # puts @a.sql_for_select(:first, :conditions => {:keyval => keyval})
      a = assert{ @a.find(:first, :conditions => {:keyval => keyval}) }
      assert{ a.keyval.keys.map(&:to_s).sort==keyval.keys.map(&:to_s).sort }
      assert{ a.keyval.values.sort==keyval.values.sort }
    end
  end

end
