
if true # test(?e, $test_integration_setup_guard)

  testing 'teardown' do

    should('nuke domains for all test models') do
      assert_nothing_raised do
        models.each do |model|
          model.delete_domain
        end
      end
      # assert_nothing_raised{ File.unlink($test_integration_setup_guard) }
      # assert !test(?e, $test_integration_setup_guard)
    end
  end

else

  puts
  puts '*** nothing to teardown ***'
  puts

end
