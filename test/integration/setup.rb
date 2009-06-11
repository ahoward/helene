
if test(?e, $test_integration_setup_guard)

  puts
  puts '*** setup has already run ***'
  puts

else

  testing 'setup' do

    context('migrating') do
      should('allow some basic models to be migrated') do
        models.threadify do |model|
          assert_nothing_raised do
            model.delete_domain rescue nil
            model.create_domain
          end
        end
        require 'time'
        open($test_integration_setup_guard, 'w'){|fd| fd.puts Time.now.iso8601(2)}
      end
    end

  end

end
