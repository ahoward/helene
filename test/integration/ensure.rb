
testing 'ensure' do
  should 'clean out all test models' do
    models.threadify do |model|
      assert_nothing_raised{ model.all.threadify{|record| record.delete} }
    end
  end
end
