require 'rspec'
require 'childprocess'

Result = Struct.new :code, :stdout, :stderr, :pid

def run(stdin:, program:, argv:)
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
  # child.io.stdin.binmode
  # child.io.stdin.sync = true
  stdin.each_char { |c| child.io.stdin.write c }
  child.io.stdin.close
  child.wait
  # if timeout
  #   child.poll_for_exit(timeout_seconds)
  # else
  #   child.wait
  # end
  Result.new(
    child.exit_code,
    read_stdout.read,
    read_stderr.read,
    child.pid,
  )
ensure
  # child.stop
  [read_stdout, read_stderr].each { |s| s.close unless s.closed? }
end


RSpec.describe 'the process' do
  it 'can echo stdin to stdout' do
    result = run stdin: "abc", program: 'ruby', argv: ['-e', '$stdout.puts $stdin.gets']
    expect(result.code).to eq 0
    expect(result.stdout).to eq "abc\n"
    expect(result.stderr).to eq ""
    # how to check the process is dead?
  end

  xit 'can echo stdin to stderr' do
    read_stdout, write_stdout = IO.pipe
    read_stderr, write_stderr = IO.pipe
    child = ChildProcess.build 'ruby', '-e', '$stderr.puts $stdin.gets'
    child.duplex = true
    child.io.stdout = write_stdout
    child.io.stderr = write_stderr
    child.start
    write_stdout.close
    write_stderr.close
    child.io.stdin.puts "abc"
    child.io.stdin.close
    child.wait
    expect(child.exit_code).to eq 0
    expect(read_stdout.read).to eq "abc\n"
    expect(read_stderr.read).to eq ""
  end

  it 'cleans up the process and all its children after a timeout'
  it 'cleans up the process and all its children when the parent is interrupted'
end
