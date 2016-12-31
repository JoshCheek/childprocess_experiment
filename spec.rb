require 'rspec'
require_relative 'run'

RSpec.describe 'the process' do
  def assert_dead(pids)
    Array(pids).each do |pid|
      if ChildProcess.windows?
        ChildProcess::Windows::Lib.alive? pid
      else
        message = <<-MESSAGE.gsub(/^ */, '')
          Expected Errno::ESRCH when checking pid #{pid.inspect},
          Which means that it can't find the process (b/c its dead)
          This was not raised, which means you should have orphans
          So check your processes to make sure. If you have them, kill them by hand,
          if not, this test needs to be improved to actually check for orphans.
        MESSAGE
        expect { Process.kill 0, pid }.to raise_error(Errno::ESRCH), message
      end
    end
  end

  it 'can echo stdin to stdout' do
    result = run stdin: "abc", program: 'ruby', argv: ['-e', '$stdout.puts $stdin.gets']
    expect(result.code).to eq 0
    expect(result.stdout.chomp).to eq "abc"
    expect(result.stderr).to eq ""
  end

  it 'can echo stdin to stderr' do
    result = run stdin: "abc", program: 'ruby', argv: ['-e', '$stderr.puts $stdin.gets']
    expect(result.code).to eq 0
    expect(result.stdout).to eq ""
    expect(result.stderr.chomp).to eq "abc"
  end

  it 'times out on stuck processes' do
    start_time = Time.now
    result = run stdin: "abc", program: 'ruby', argv: ['-e', 'sleep'], timeout: 1
    end_time = Time.now
    expect(end_time - start_time).to be > 1
    assert_dead result.pid
  end

  it 'cleans up the process and all its children after a timeout' do
    start_time = Time.now
    result = run stdin: "abc", program: 'ruby', argv: ['-e', '
      puts $$
      pid = spawn %(ruby), %(-e), %(sleep)
      puts pid
      $stdout.flush
      sleep
    '], timeout: 1
    end_time = Time.now

    # it did timeout
    expect(result.code).to_not eq 0
    expect(result.code).to be_a_kind_of Integer
    expect(end_time - start_time).to be > 1

    # the two children printed their pids
    pids = result.stdout.lines.map do |line|
      expect(line.chomp).to match /^\d+\r?\n?$/
      line.to_i
    end
    expect(pids.length).to eq 2
    expect(pids[0]).to eq result.pid # sanity check
    assert_dead pids
  end

  it 'cleans up the process and all its children when the parent is interrupted' do
    read, write = IO.pipe
    filepath = File.realpath('run', __dir__)
    program = ChildProcess.build 'ruby', filepath, '--', 'ruby', '-e', '
      puts $$
      pid = spawn %(ruby), %(-e), %(sleep)
      puts pid
      $stdout.flush
      sleep
    '
    program.io.stdout = write
    program.io.stderr = write
    program.start
    write.close

    # get the pids
    child_pid = read.gets
    grandchild_pid = read.gets
    expect(child_pid).to match /^\d+$/
    expect(grandchild_pid).to match /^\d+$/

    # interrupt the program
    program.stop

    assert_dead [program.pid, child_pid.to_i, grandchild_pid.to_i]
  end

  xit 'cleans up the process and all its children when the child exits normally' do
    result = run stdin: "abc", program: 'ruby', argv: ['-e', '
      puts $$
      read, write = IO.pipe
      spawn "ruby", "-e", "puts $$; $stdout.flush; $stderr.puts :started; $stderr.close; sleep", err: write
      write.close
      read.gets
      read.close
    ']

    # printed and exited like we expect
    expect(result.stderr).to be_empty
    expect(result.stdout).to match /^#{result.pid}\n(\d+)$/
    grandchild_pid = result.stdout.lines.last.to_i
    expect(result.code).to eq 0

    # killed the children
    assert_dead result.pid
    assert_dead grandchild_pid
  end
end
