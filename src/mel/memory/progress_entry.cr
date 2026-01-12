module Mel
  struct Memory
    struct ProgressEntry
      getter :value

      getter expire : Time?

      def initialize(@value : String)
        @expire = Mel.settings.progress_expiry.try(&.from_now)
      end

      def expired? : Bool
        !!expire.try { |expire| expire <= Time.local }
      end
    end
  end
end
