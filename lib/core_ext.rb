# frozen_string_literal: true

# require 'concurrent/map'

# Overrides
class Object
  # An object is blank if it's false, empty, or a whitespace string.
  # For example, +nil+, '', '   ', [], {}, and +false+ are all blank.
  #
  # This simplifies
  #
  #   !address || address.empty?
  #
  # to
  #
  #   address.blank?
  #
  # @return [true, false]
  def blank?
    respond_to?(:empty?) ? !!empty? : !self
  end

  # An object is present if it's not blank.
  #
  # @return [true, false]
  def present?
    !blank?
  end

  # Returns the receiver if it's present otherwise returns +nil+.
  # <tt>object.presence</tt> is equivalent to
  #
  #    object.present? ? object : nil
  #
  # For example, something like
  #
  #   state   = params[:state]   if params[:state].present?
  #   country = params[:country] if params[:country].present?
  #   region  = state || country || 'US'
  #
  # becomes
  #
  #   region = params[:state].presence || params[:country].presence || 'US'
  #
  # @return [Object]
  def presence
    self if present?
  end
end

class NilClass
  # +nil+ is blank:
  #
  #   nil.blank? # => true
  #
  # @return [true]
  def blank?
    true
  end
end

class FalseClass
  # +false+ is blank:
  #
  #   false.blank? # => true
  #
  # @return [true]
  def blank?
    true
  end
end

class TrueClass
  # +true+ is not blank:
  #
  #   true.blank? # => false
  #
  # @return [false]
  def blank?
    false
  end
end

class Array
  # An array is blank if it's empty:
  #
  #   [].blank?      # => true
  #   [1,2,3].blank? # => false
  #
  # @return [true, false]
  alias blank? empty?
end

class Hash
  # A hash is blank if it's empty:
  #
  #   {}.blank?                # => true
  #   { key: 'value' }.blank?  # => false
  #
  # @return [true, false]
  alias blank? empty?

  # Recursively merges self with another hash.
  # If a value is a hash and the same key exists in both, it merges them.
  # Otherwise, the value from the other hash overwrites the original.
  def deep_merge(other_hash)
    merge(other_hash) do |_key, oldval, newval|
      if oldval.is_a?(Hash) && newval.is_a?(Hash)
        oldval.deep_merge(newval)
      else
        newval
      end
    end
  end
end

class String
  BLANK_RE = /\A[[:space:]]*\z/.freeze
  # ENCODED_BLANKS = Concurrent::Map.new do |h, enc|
  #   h[enc] = Regexp.new(BLANK_RE.source.encode(enc), BLANK_RE.options | Regexp::FIXEDENCODING)
  # end

  # A string is blank if it's empty or contains whitespaces only:
  #
  #   ''.blank?       # => true
  #   '   '.blank?    # => true
  #   "\t\n\r".blank? # => true
  #   ' blah '.blank? # => false
  #
  # Unicode whitespace is supported:
  #
  #   "\u00a0".blank? # => true
  #
  # @return [true, false]
  def blank?
    # The regexp that matches blank strings is expensive. For the case of empty
    # strings we can speed up this method (~3.5x) with an empty? call. The
    # penalty for the rest of strings is marginal.
    empty? ||
      begin
        BLANK_RE.match?(self)
      rescue Encoding::CompatibilityError
        false
      end
  end

  def parameterize
    # Remove all non-alphanumeric characters and convert to lowercase removing trailing underscores
    downcase.gsub(/[^a-z0-9]+/, '_').gsub(/_$/, '')
  end

  # ANSI color codes for terminal output
  def colorize(color_code)
    return self unless $stdout.tty?
    "\e[#{color_code}m#{self}\e[0m"
  end

  def red
    colorize(31)
  end

  def green
    colorize(32)
  end

  def yellow
    colorize(33)
  end

  def blue
    colorize(34)
  end

  def magenta
    colorize(35)
  end

  def cyan
    colorize(36)
  end

  def bold
    colorize(1)
  end
end

class Numeric # :nodoc:
  # No number is blank:
  #
  #   1.blank? # => false
  #   0.blank? # => false
  #
  # @return [false]
  def blank?
    false
  end
end

class Time # :nodoc:
  # No Time is blank:
  #
  #   Time.now.blank? # => false
  #
  # @return [false]
  def blank?
    false
  end
end

# Adds a progress enabled enumerable method
module Enumerable
  def each_slice_with_progress(size)
    # Prefer O(1) if available; fall back to count
    total = respond_to?(:length) ? length : count

    # If no block, return an enumerator that will yield [slice, total, done, percent]
    return enum_for(:each_slice_with_progress, size) { (total.to_f / size).ceil } unless block_given?

    i = 0
    each_slice(size) do |slice|
      i += 1
      done    = [i * size, total].min
      percent = total.zero? ? 100 : ((done.to_f / total) * 100).round
      yield(slice, total, done, percent)
    end
  end
end
