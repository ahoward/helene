
if test(?e, $test_integration_setup_guard)

  testing 'teardown' do

    should('let setup run again') do
      assert_nothing_raised{ File.unlink($test_integration_setup_guard) }
      assert !test(?e, $test_integration_setup_guard)
    end
  end

else

  puts
  puts '*** nothing to teardown ***'
  puts

end
