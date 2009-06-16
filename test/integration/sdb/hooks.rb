testing Helene::Sdb::Base do

  context 'hooks' do
    setup do
      @a = model(:a) do
        attribute :x, :string
        before_save{ update :x => '42' }
      end
    end

    perform = 'before_save'
    should perform do
      a = assert{ @a.create! }
      assert{ a.x=='42' }
      eventually_assert(perform){ a.reload; a.x=='42' }
    end
  end

end
