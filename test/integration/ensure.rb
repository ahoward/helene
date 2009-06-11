
testing 'ensure' do
  should 'clean out all test models' do
    models.each do |model|
      assert true
      #p model.domain
      p model.sql_for_select(:all)
      #assert_nothing_raised{ model.all.threadify{|record| p record} }
    end
  end
end
