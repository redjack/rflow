class RFlow
  module Components
    module Raw
      module Extensions
        module RawExtension
          def self.extended(base_data)
            base_data.data_object ||= {'raw' => ''}
          end

          def raw; data_object['raw']; end
          def raw=(new_raw); data_object['raw'] = new_raw; end
        end
      end
    end
  end
end
