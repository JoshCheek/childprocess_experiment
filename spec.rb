require 'rspec'
require_relative 'run'

RSpec.describe 'the process' do
  it 'can echo stdin to stdout' do
    result = run stdin: "abc", program: 'ruby', argv: ['-e', '$stdout.puts $stdin.gets']
    expect(result.code).to eq 0
    expect(result.stdout).to eq "abc\n"
    expect(result.stderr).to eq ""
  end

  it 'can echo stdin to stderr' do
    result = run stdin: "abc", program: 'ruby', argv: ['-e', '$stderr.puts $stdin.gets']
    expect(result.code).to eq 0
    expect(result.stdout).to eq ""
    expect(result.stderr).to eq "abc\n"
  end

  it 'times out on stuck processes' do
    start_time = Time.now
    result = run stdin: "abc", program: 'ruby', argv: ['-e', 'sleep'], timeout: 1
    end_time = Time.now
    expect(end_time - start_time).to be > 1

    # this error should mean that it can't find the process, ie b/c its dead
    # if it fails this, then check your processes, it should have orphans
    expect { Process.kill 0, result.pid }.to raise_error Errno::ESRCH
  end

  # how to check the process is dead?
  it 'cleans up the process and all its children after a timeout' do
    start_time = Time.now
    result = run stdin: "abc", program: 'ruby', argv: ['-e', '
      puts $$
      spawn "ruby", "-e", "puts $$; $stdout.flush; sleep"
      sleep
    '], timeout: 1
    end_time = Time.now

    # it did timeout
    expect(end_time - start_time).to be > 1
    expect(result.code).to eq 1

    # the two children printed their pids
    pids = result.stdout.lines.map do |line|
      expect(line).to match /^\d+$/
      line.to_i
    end
    expect(pids.length).to eq 2
    expect(pids[0]).to eq result.pid # sanity check

    # they are both dead
    pids.each do |pid|
      # this error should mean that it can't find the process, ie b/c its dead
      expect { Process.kill 0, pid }.to raise_error Errno::ESRCH
    end
  end

  it 'cleans up the process and all its children when the parent is interrupted' do

  end
end
