require 'timeout'

Result = Struct.new :code, :stdout, :stderr, :pid, :pgid, :timed_out do
  alias timed_out? timed_out
end

# what is the difference between the group id and the effective group id?
# there are also sessions

def run(stdin:, program:, argv:, timeout: 0, write_stdout:nil, write_stderr:nil)
  result = Result.new

  # setup pipes
  read_stdout, write_stdout = IO.pipe unless write_stdout
  read_stderr, write_stderr = IO.pipe unless write_stderr
  read_stdin,  write_stdin  = IO.pipe

  # spawn
  result.pid = spawn program, *argv, pgroup: true, in: read_stdin, out: write_stdout, err: write_stderr
  old_int_handler = trap 'INT' do
    kill! result
    trap old_int_handler
    Process.kill 'INT', $$
  end
  result.pgid = Process.getpgid(result.pid)

  # close pipes in parent so that child has the last open handle
  # thus closing them in the child closes them completely
  read_stdin.close
  write_stdout.close if read_stdout
  write_stderr.close if read_stderr

  # send standard input
  write_stdin.sync = true
  stdin.each_char { |c| write_stdin.write c }
  write_stdin.close

  # wait for result, timeout if it takes too long
  Timeout.timeout timeout do
    Process.wait result.pid
    result.code = $?.exitstatus
  end

rescue Timeout::Error
  result.timed_out = true
  kill! result
ensure
  result.stdout = read_and_close(read_stdout)
  result.stderr = read_and_close(read_stderr)
  return result unless $!
end

def read_and_close(stream)
  return "" unless stream
  printed = ""
  loop do
    readable, _ = IO.select [stream], [$stdout]
    break unless readable.any?
    begin
      printed += stream.readpartial(1)
    rescue EOFError
      break
    end
  end
  stream.close
  printed
end

def kill!(result)
  Process.kill '-KILL', result.pgid
  Process.wait result.pid
  result.code = $?.exitstatus || 1
end
