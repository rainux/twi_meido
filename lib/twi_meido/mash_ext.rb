class Hashie::Mash
  class << self
    def to_mongo(value)
      value.to_hash if value
    end

    def from_mongo(value)
      new(value)
    end
  end
end
