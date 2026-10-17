# The RowLocking module provides a mechanism for exclusive row access,
# similar to the swap-file locking used by Vim.
#
# It prevents multiple concurrent instances of the application from modifying
# the same database row, thereby avoiding race conditions and state collision.
# The lock is based on the Process ID (PID) and is validated by checking if
# the owning process is still active on the system.
#
# This module is intended to be mixed into any Sequel model that has a
# `locked_by_pid` column.
module OllamaChat::Database::RowLocking
  # Checks if the row is currently locked by an active process.
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

  # Attempts to acquire a lock on the row.
  #
  # @return [Boolean] true if the lock was successfully acquired, false if already locked.
  def lock?
    return false if locked?
    !!lock
  end

  # Sets the lock for the current process.
  #
  # @return [Boolean] true if the update was successful.
  def lock
    update(locked_by_pid: $$)
  end

  # Releases the lock on the row.
  #
  # @return [Boolean] true if the update was successful.
  def unlock
    update(locked_by_pid: nil)
  end
end
