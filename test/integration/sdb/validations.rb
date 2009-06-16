testing Helene::Sdb::Base do

  context "validations" do
    context ":on => :create" do
      setup do
        @a = model(:a) do
          attribute :mode, :string
          validates_format_of :mode, :with => /\Acreate\z/, :on => :create
        end
      end

      should "only be checked for creation" do
        a = assert{ @a.new(:mode => "bad") }
        assert{ !a.valid? }
        a.mode = "create"
        assert{ a.save! }
        a.mode = "update"
        assert{ a.valid? }
      end
    end

    context ":on => :update" do
      setup do
        @a = model(:a) do
          attribute :mode, :string
          validates_format_of :mode, :with => /\Aupdate\z/, :on => :update
        end
      end

      should "only be checked for updates" do
        a = assert{ @a.new(:mode => "create") }
        assert{ a.save! }
        assert{ !a.valid? }
        a.mode = "update"
        assert{ a.valid? }
      end
    end

    context ":on => :save" do
      setup do
        @a = model(:a) do
          attribute :mode, :string
          validates_format_of :mode, :with => /\Asave\z/, :on => :save
        end
      end

      should "always be checked" do
        a = assert{ @a.new(:mode => "bad") }
        assert{ !a.valid? }
        a.mode = "save"
        assert{ a.save! }
        a.mode = "update"
        assert{ !a.valid? }
        a.mode = "save"
        assert{ a.valid? }
      end
    end
  end

end
