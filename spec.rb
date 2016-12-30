require 'rspec'
require 'childprocess'

Result = Struct.new :code, :stdout, :stderr, :pid, :timed_out do
  alias timed_out? timed_out
end

def run(stdin:, program:, argv:, timeout: nil)
  read_stdout, write_stdout = IO.pipe
  read_stderr, write_stderr = IO.pipe
  child = ChildProcess.build program, *argv
  # child.leader = true
  child.duplex    = true
  child.io.stdout = write_stdout
  child.io.stderr = write_stderr
  child.start
  write_stdout.close
  write_stderr.close
  result = Result.new
  result.pid = child.pid
  # child.io.stdin.binmode
  # child.io.stdin.sync = true
  stdin.each_char { |c| child.io.stdin.write c }
  child.io.stdin.close
  if timeout
    puts "WAITING"
    child.poll_for_exit(timeout)
  else
    child.wait
  end
  child.exit_code
rescue ChildProcess::TimeoutError
  puts "TIMED OUT"
  result.timed_out = true
ensure
  if child.stop
    puts "GETTING CODE"
    result.code = child.exit_code
  else
    puts "Using a code of 1"
    result.code = 1
  end
  result.stdout = read_and_close(read_stdout)
  result.stderr = read_and_close(read_stderr)
  return result
end

def read_and_close(stream)
  read = ""
  loop do
    readable, _ = IO.select [stream], [$stdout]
    break unless readable.any?
    begin
      read += stream.readpartial(1)
    rescue EOFError
      break
    end
  end
  stream.close
  read
end


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

    # this should mean that it can't find the process
    expect { Process.kill 0, result.pid }.to raise_error Errno::ESRCH
  end

  # how to check the process is dead?
  xit 'cleans up the process and all its children after a timeout' do
    start_time = Time.now
    result = run stdin: "abc", program: 'ruby', argv: ['-e', '
      puts $$
      spawn "ruby", "-e", "puts $$; $stdout.flush; sleep"
      sleep
    '], timeout: 1
    end_time = Time.now
    p end_time - start_time
    expect(end_time - start_time).to be > 1
    expect(result.code).to eq 1
    # expect(result.stdout).to eq ""
  end

  it 'cleans up the process and all its children when the parent is interrupted'
end
