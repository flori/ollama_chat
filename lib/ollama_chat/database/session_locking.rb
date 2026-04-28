# The SessionLocking module provides a mechanism for exclusive session access,
# similar to the swap-file locking used by Vim.
#
# It prevents multiple concurrent instances of the application from modifying
# the same session, thereby avoiding race conditions and context collision.
# The lock is based on the Process ID (PID) and is validated by checking if
# the owning process is still active on the system.
#
# This module is intended to be mixed into models that persist session state,
# such as OllamaChat::Database::Models::Session.
module OllamaChat::Database::SessionLocking
  # Checks if the session is currently locked by an active process.
  #
  # @return [Integer, nil] the PID of the locking process if active, or nil if unlocked/stale.
  def locked?
    locked_pid = locked_by_pid
    locked_pid.nil? and return
    begin
      Process.kill(0, locked_pid)
      locked_pid
    rescue Errno::ESRCH
      nil
    end
  end

  # Attempts to acquire a lock on the session.
  #
  # @return [Boolean] true if the lock was successfully acquired, false if already locked.
  def lock?
    if running_pid = locked?
      STDERR.puts "session #{id} locked by running process #{running_pid}"
      false
    else
      lock
    end
  end

  # Sets the lock for the current process.
  #
  # @return [Boolean] true if the update was successful.
  def lock
    update(locked_by_pid: $$)
  end

  # Releases the lock on the session.
  #
  # @return [Boolean] true if the update was successful.
  def unlock
    update(locked_by_pid: nil)
  end
end
