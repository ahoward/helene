testing Helene::Sdb::Base do

  context 'associations' do
    context 'has_many' do
      setup do
        @a = model(:a) do
          has_many :bs
        end
        @b = model(:b) do
          attribute :a_id
        end
      end

      should 'support simple has_many' do
        a = assert{ @a.create! }
        assert{ a.respond_to?(:bs) }
        b = assert{ @b.create! }
        assert{ b.respond_to?(:a_id) }
        assert{ a.bs << b }
        assert{ b.a_id == a.id }
      end
    end

    context 'has_one' do
      setup do
        @a = model(:a) do
          has_one :b
        end
        @b = model(:b) do
          attribute :a_id
        end
      end

      should 'support simple has_one' do
        a = assert{ @a.create! }
        assert{ a.respond_to?(:b) }
        b = assert{ @b.create! }
        assert{ b.respond_to?(:a_id) }
        assert{ a.b = b }
        assert{ b.a_id == a.id }
      end
    end
  end

end
