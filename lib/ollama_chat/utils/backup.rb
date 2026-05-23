# Utility module for handling file backups.
# This module provides methods to create timestamped copies of files
# in a designated backup directory within the XDG state home.
module OllamaChat::Utils::Backup
  # Creates a timestamped backup of the specified file.
  #
  # The backup is stored in {OC::XDG_STATE_HOME}/backups, preserving
  # the original directory structure.
  #
  # @param path [Pathname, String] the path to the file that should be backed up.
  # @return [Pathname] backup path to the file that was created for backup
  def perform_backup(path)
    path.exist? or return
    backups_dir = OC::XDG_STATE_HOME + 'backups'
    timestamp   = Time.now.strftime('%Y%m%d%H%M%S')
    backup_path = Pathname.new(backups_dir.to_s + path.to_s + ?- + timestamp)
    backup_path.dirname.mkpath
    FileUtils.cp path, backup_path
    backup_path
  end
end
