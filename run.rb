require 'childprocess'

Result = Struct.new :code, :stdout, :stderr, :pid, :timed_out do
  alias timed_out? timed_out
end

def run(stdin:, program:, argv:, timeout: nil, write_stdout:nil, write_stderr:nil)
  read_stdout, write_stdout = IO.pipe unless write_stdout
  read_stderr, write_stderr = IO.pipe unless write_stderr
  child = ChildProcess.build program, *argv
  child.leader    = true
  child.duplex    = true
  child.io.stdout = write_stdout
  child.io.stderr = write_stderr
  child.start
  write_stdout.close if read_stdout
  write_stderr.close if read_stderr
  result = Result.new
  result.pid = child.pid
  # child.io.stdin.binmode
  # child.io.stdin.sync = true
  stdin.each_char { |c| child.io.stdin.write c }
  child.io.stdin.close
  if timeout
    child.poll_for_exit(timeout)
  else
    child.wait
  end
  result.code = child.exit_code
rescue ChildProcess::TimeoutError
  puts "TIMED OUT"
  result.timed_out = true
  child.stop
  result.code = child.exit_code
ensure
  if $!
    begin
      child.stop
    rescue NoMethodError
    end
    result.code = child.exit_code
  end
  result.stdout = read_and_close(read_stdout)
  result.stderr = read_and_close(read_stderr)
  return result unless $!
end

def read_and_close(stream)
  return "" unless stream
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
