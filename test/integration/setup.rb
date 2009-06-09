
if test(?e, $test_integration_setup_guard)

  puts
  puts '*** setup has already run ***'
  puts

else

  testing 'setup' do

    context('migrating') do
      should('allow some basic models to be migrated') do
        class A < Helene::Sdb::Base; end
        class B < Helene::Sdb::Base; end
        class C < Helene::Sdb::Base; end

        [A, B, C].each do |model|
          assert_nothing_raised{ model.migrate!  }
          record = assert{ model.create }
          assert{ record.delete; true }
        end
      end
    end

  end

end
