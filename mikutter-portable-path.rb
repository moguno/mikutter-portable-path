#coding: UTF-8

Plugin.create(:"mikutter-portable-path") {

  # パスをポータブル化したり元に戻したりするモジュール
  module PortablePath
    # ディレクトリとシンボルの対応表
    REL_DIR_TABLE = [
      { :symbol => "{MIKUTTER_DIR}", :path => FOLLOW_DIR },
      { :symbol => "{CONFROOT}", :path => Environment::CONFROOT },
    ]

    # パスをポータブル化する
    def port_path(path)
      rel_item = REL_DIR_TABLE.find { |_| path =~ /^#{_[:path]}/ }

      portable_path = if rel_item
        path.sub(/^#{rel_item[:path]}/, "#{rel_item[:symbol]}")
      else
        path
      end

      portable_path
    end

    # ポータブルなパスを今の環境のフルパスに戻す
    def expand_portable_path(portable_path)
      rel_item = REL_DIR_TABLE.find { |_| portable_path =~ /^#{_[:symbol]}/ }

      real_path = if rel_item
        portable_path.sub(/^#{rel_item[:symbol]}/, "#{rel_item[:path]}")
      else
        portable_path
      end

      real_path
    end
  end

  # モンキーパッチ用にPluginクラスを開く
  class Plugin
    class << self
      include PortablePath

      alias :call_org :call

      # ポータブルなパスを扱うことになるイベントを水際で捕まえてフルパスに変換する
      def call(event_name, *args)
        case event_name
        when :play_sound
          call_org(event_name, expand_portable_path(args[0]), *args[1..-1])

        when :gui_tab_change_icon
          args[0].set_icon(expand_portable_path(args[0].icon))
          call_org(event_name, *args)

        else
          call_org(event_name, *args)
        end
      end
    end
  end

  # モンキーパッチ用にFileChooserDialogクラスを開く
  class Gtk::FileChooserDialog
    include PortablePath

    alias :filename_org :filename
    alias :run_org :run

    # 備え付けのfilenameはfilename=で代入するとnilが返ってくるのでモンキーパッチする
    @_filename = ""

    def filename
      @_filename
    end

    # 選択したファイルをポータブルな形式に変換する
    def run(*args)
      result = run_org(*args)

      @_filename = port_path(self.filename_org.gsub(/\\/, "/"))

      result 
    end
  end

  # モンキーパッチようにFileTestモジュールを開く
  module FileTest
    class << self
      include PortablePath

      alias :exist_org? :exist?

      # notify.rbでplay_soundイベントを呼ぶ前にサウンドファイルの存在有無を確かめてるので、それをごまかす。
      def exist?(file)
        exist_org?(expand_portable_path(file))
      end
    end
  end
}
