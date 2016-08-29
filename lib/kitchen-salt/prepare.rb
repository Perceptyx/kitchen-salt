require 'fileutils'

module Kitchen
  module Salt
    module Prepare
      private

      def prepare_data
        return unless config[:data_path]

        info('Preparing data')
        debug("Using data from #{config[:data_path]}")

        tmpdata_dir = File.join(sandbox_path, 'data')
        FileUtils.mkdir_p(tmpdata_dir)
        cp_r_with_filter(config[:data_path], tmpdata_dir, config[:salt_copy_filter])
      end

      def prepare_minion
        info('Preparing salt-minion')

        minion_config_content = <<-MINION_CONFIG.gsub(/^ {10}/, '')
          state_top: top.sls

          file_client: local

          file_roots:
           #{config[:salt_env]}:
             - #{File.join(config[:root_path], config[:salt_file_root])}

          pillar_roots:
           #{config[:salt_env]}:
             - #{File.join(config[:root_path], config[:salt_pillar_root])}
        MINION_CONFIG

        # create the temporary path for the salt-minion config file
        debug("sandbox is #{sandbox_path}")
        sandbox_minion_config_path = File.join(sandbox_path, config[:salt_minion_config])

        write_raw_file(sandbox_minion_config_path, minion_config_content)
      end

      def prepare_state_top
        info('Preparing state_top')

        sandbox_state_top_path = File.join(sandbox_path, config[:salt_state_top])

        if config[:state_top_from_file] == false
          # use the top.sls embedded in .kitchen.yml

          # we get a hash with all the keys converted to symbols, salt doesn't like this
          # to convert all the keys back to strings again
          state_top_content = unsymbolize(config[:state_top]).to_yaml
          # .to_yaml will produce ! '*' for a key, Salt doesn't like this either
          state_top_content.gsub!(/(!\s'\*')/, "'*'")
        else
          # load a top.sls from disk
          state_top_content = File.read('top.sls')
        end

        write_raw_file(sandbox_state_top_path, state_top_content)
      end

      def prepare_pillars
        info("Preparing pillars into #{config[:salt_pillar_root]}")
        debug("Pillars Hash: #{config[:pillars]}")

        return if config[:pillars].nil? && config[:'pillars-from-files'].nil?

        # we get a hash with all the keys converted to symbols, salt doesn't like this
        # to convert all the keys back to strings again
        pillars = unsymbolize(config[:pillars])
        debug("unsymbolized pillars hash: #{pillars}")

        # write out each pillar (we get key/contents pairs)
        pillars.each do |key, contents|
          # convert the hash to yaml
          pillar = contents.to_yaml

          # .to_yaml will produce ! '*' for a key, Salt doesn't like this either
          pillar.gsub!(/(!\s'\*')/, "'*'")

          # generate the filename
          sandbox_pillar_path = File.join(sandbox_path, config[:salt_pillar_root], key)

          debug("Rendered pillar yaml for #{key}:\n #{pillar}")
          write_raw_file(sandbox_pillar_path, pillar)
        end

        # copy the pillars from files straight across, as YAML.load/to_yaml and
        # munge multiline strings
        unless config[:'pillars-from-files'].nil?
          external_pillars = unsymbolize(config[:'pillars-from-files'])
          debug("external_pillars (unsymbolize): #{external_pillars}")
          external_pillars.each do |key, srcfile|
            debug("Copying external pillar: #{key}, #{srcfile}")
            # generate the filename
            sandbox_pillar_path = File.join(sandbox_path, config[:salt_pillar_root], key)
            # create the directory where the pillar file will go
            FileUtils.mkdir_p(File.dirname(sandbox_pillar_path))
            # copy the file across
            FileUtils.copy srcfile, sandbox_pillar_path
          end
        end
      end

      def prepare_grains
        debug("Grains Hash: #{config[:grains]}")

        return if config[:grains].nil?

        info("Preparing grains into #{config[:salt_config]}/grains")

        # generate the filename
        sandbox_grains_path = File.join(sandbox_path, config[:salt_config], 'grains')

        debug("sandbox_grains_path: #{sandbox_grains_path}")
        write_hash_file(sandbox_grains_path, config[:grains])
      end

      def prepare_formula(path, formula)
        info("Preparing formula: #{formula} from #{path}")
        debug("Using config #{config}")

        formula_dir = File.join(sandbox_path, config[:salt_file_root], formula)
        FileUtils.mkdir_p(formula_dir)
        cp_r_with_filter(File.join(path, formula), formula_dir, config[:salt_copy_filter])

        # copy across the _modules etc directories for python implementation
        %w(_modules _states _grains _renderers _returners).each do |extrapath|
          src = File.join(path, extrapath)

          if File.directory?(src)
            debug("prepare_formula: #{src} exists, copying..")
            extrapath_dir = File.join(sandbox_path, config[:salt_file_root], extrapath)
            FileUtils.mkdir_p(extrapath_dir)
            cp_r_with_filter(src, extrapath_dir, config[:salt_copy_filter])
          else
            debug("prepare_formula: #{src} doesn't exist, skipping.")
          end
        end
      end

      def prepare_state_collection
        info('Preparing state collection')
        debug("Using config #{config}")

        if config[:collection_name].nil? && config[:formula].nil?
          info('neither collection_name or formula have been set, assuming this is a pre-built collection')
          config[:collection_name] = ''
        elsif config[:collection_name].nil?
          debug("collection_name not set, using #{config[:formula]}")
          config[:collection_name] = config[:formula]
        end

        debug("sandbox_path = #{sandbox_path}")
        debug("salt_file_root = #{config[:salt_file_root]}")
        debug("collection_name = #{config[:collection_name]}")
        collection_dir = File.join(sandbox_path, config[:salt_file_root], config[:collection_name])
        FileUtils.mkdir_p(collection_dir)
        cp_r_with_filter(config[:kitchen_root], collection_dir, config[:salt_copy_filter])
      end
    end
  end
end
