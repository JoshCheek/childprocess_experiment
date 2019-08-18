task :default do
  begin
    sh 'ruby', '-r', 'thread', '-e', 'Thread.new { Queue.new.shift }.join'
  rescue
    puts $!
  end
  sh 'bundle', 'exec', 'rspec', 'spec.rb', '--format', 'documentation', '--fail-fast', '--color'
end
