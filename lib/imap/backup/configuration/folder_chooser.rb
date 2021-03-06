module Imap::Backup
  module Configuration; end

  class Configuration::FolderChooser
    attr_reader :account

    def initialize(account)
      @account = account
    end

    def run
      if connection.nil?
        Imap::Backup.logger.warn "Connection failed"
        highline.ask "Press a key "
        return
      end

      if folders.nil?
        Imap::Backup.logger.warn "Unable to get folder list"
        highline.ask "Press a key "
        return
      end

      remove_missing

      catch :done do
        loop do
          Kernel.system("clear")
          show_menu
        end
      end
    end

    private

    def show_menu
      highline.choose do |menu|
        menu.header = "Add/remove folders"
        menu.index = :number
        add_folders menu
        menu.choice("return to the account menu") { throw :done }
        menu.hidden("quit") { throw :done }
      end
    end

    def add_folders(menu)
      folders.each do |folder|
        name = folder.name
        mark = selected?(name) ? "+" : "-"
        menu.choice("#{mark} #{name}") do
          toggle_selection name
        end
      end
    end

    def selected?(folder_name)
      backup_folders = account[:folders]
      return false if backup_folders.nil?

      backup_folders.find { |f| f[:name] == folder_name }
    end

    def remove_missing
      removed = []
      backup_folders = []
      account[:folders].each do |f|
        found = folders.find { |folder| folder.name == f[:name] }
        if found
          backup_folders << f
        else
          removed << f[:name]
        end
      end

      return if removed.empty?

      account[:folders] = backup_folders
      account[:modified] = true

      Kernel.puts <<~MESSAGE
        The following folders have been removed: #{removed.join(', ')}
      MESSAGE

      highline.ask "Press a key "
    end

    def toggle_selection(folder_name)
      if selected?(folder_name)
        changed = account[:folders].reject! { |f| f[:name] == folder_name }
        account[:modified] = true if changed
      else
        account[:folders] ||= []
        account[:folders] << {name: folder_name}
        account[:modified] = true
      end
    end

    def connection
      @connection ||= Account::Connection.new(account)
    rescue StandardError
      nil
    end

    def folders
      @folders ||= connection.folders
    end

    def highline
      Configuration::Setup.highline
    end
  end
end
