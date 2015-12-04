threads = []

[8, 5, 1, 0, 0.3].each do |n|
  threads << Thread.new do
    sleep n.to_f
    puts n
  end
end

threads.each do |t|
  t.join
end