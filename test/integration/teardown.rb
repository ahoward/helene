
if true # test(?e, $test_integration_setup_guard)

  testing 'teardown' do

    should('nuke domains for all test models') do
      models.threadify do |model|
        model.delete_domain rescue nil
      end
      File.unlink($test_integration_setup_guard) rescue nil
      assert !test(?e, $test_integration_setup_guard)
    end
  end

else

  puts
  puts '*** nothing to teardown ***'
  puts

end
