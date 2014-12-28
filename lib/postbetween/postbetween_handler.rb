require 'functional'
require 'deterministic'
require 'active_support/core_ext/hash/indifferent_access'

class Postbetween::PostbetweenHandler
  include Functional::PatternMatching
  include Deterministic::Prelude::Result

  class RequestPart
    include Functional::PatternMatching
    @value

    defn(:initialize, _) { |val| @value = val.with_indifferent_access }
      .when { |val| val.kind_of?(Array) || val.kind_of?(Hash) }
    defn(:contents) { @value }
  end
  class Header < RequestPart
  end
  class Query < RequestPart
  end
  class Body < RequestPart
  end

  class Request
    include Functional::PatternMatching
    PART_KEYS = [:header, :body, :query]
    PART_KEYS.each { |k| attr_accessor k }

    defn(:initialize, Header, Body, Query) { |h, b, q| @header, @body, @query = h, b, q }
    defn(:part, Symbol) { |p| send(p) }
    defn(:parts) { PART_KEYS.inject({}) { |h, k| h.merge(k => send(k)) } }
  end

  class RequestPartProcessing
    include Functional::PatternMatching

    defn(:array_or_hash, _) { |v| [Array, Hash].any? { |c| v.kind_of?(c) } }

    defn(:format, String) { |k| k.to_i }
      .when { |k| k == "0" || k.to_i > 0 }
    defn(:format, String) { |k| k }
    defn(:format, "[]", Array) { |v| v.size }
    defn(:format, "[]", _) { |v| 0 }
    defn(:format, String, _) { |k, v| format(k) }

    defn(:after, Proc) do |p|
      @after = p
    end
    defn(:after) do
      @after ||= ->(x) { x }
    end
  end

  class RequestPartReader < RequestPartProcessing
    include Functional::PatternMatching

    defn(:initialize, RequestPart, String) { |p, k| @part, @key = p, k }
    defn(:initialize, RequestPart, String, ::Postbetween::PostbetweenHandler) do |p, k, h|
      @part, @key, @handler = p, k, h
    end

    defn(:read, _, _) { |v, k| after.call(v[format(k)]) }
      .when { |v, k| array_or_hash(v) }

    defn(:run, String, _, nil) { |_, _| nil }
    defn(:run, String, [], _) { |k, val| read(val, k) }
    defn(:run, String, Array, _) do |k, tail, val|
      run(tail[0], tail[1..-1], val[format(k)])
    end
    defn(:run, String, RequestPart) do |k, p|
      ks = k.split(".")
      run(ks[1], ks[2..-1], p.contents[format(ks[0])])
    end.when { |k, p| k.include?(".") }
    defn(:run, String, RequestPart) { |k, p| read(p.contents, k) }
    defn(:run) { run(@key, @part) }

    def into_outgoing(part, key, &block)
      w = RequestPartWriter.new(part, key, self)
      if block_given?
        w.instance_eval(&block)
      end
      @handler.writers << w
    end
  end

  class RequestPartWriter < RequestPartProcessing
    include Functional::PatternMatching

    defn(:initialize, Symbol, String, RequestPartReader) do |p, k, r|
      @part, @key, @reader = p, k, r
    end.when { |p, _, _| Request::PART_KEYS.include?(p) }
    defn(:initialize, Symbol, String, ::Postbetween::PostbetweenHandler) do |p, k, h|
      @part, @key, @handler = p, k, h
    end.when { |p, _, _| Request::PART_KEYS.include?(p) }

    defn(:value_or_default, _, _) { |v, _| v }
      .when { |v, _| array_or_hash(v) }
    defn(:value_or_default, _, _) { |v, k| k.kind_of?(Integer) ? [] : {} }

    defn(:hacky_deep_dupe, _) { |v| Marshal.load(Marshal.dump(v)) }

    defn(:assign, _, _, RequestPartReader) { |v, k, r| v[k] = after.call(hacky_deep_dupe(r.run)) }
      .when { |v, _, _| array_or_hash(v) }
    defn(:assign, _, _, _, RequestPartReader) { |v, k, nk, r| v[k][nk] = after.call(hacky_deep_dupe(r.run)) }
      .when { |v, _, _, _| array_or_hash(v) }

    defn(:run, String, [], _, _, RequestPartReader) do |k, lv, lk, r|
      nk = format(k, lv[lk])
      lv[lk] = value_or_default(lv[lk], nk)
      assign(lv, lk, nk, r)
    end
    defn(:run, String, RequestPart, RequestPartReader) do |k, p, r|
      assign(p.contents, k, r)
    end.when { |k, p, r| !k.include?(".") }
    defn(:run, String, Array, _, _, RequestPartReader) do |k, t, lv, lk, r|
      nk = format(k, lv[lk])
      lv[lk] = value_or_default(lv[lk], nk)
      run(t[0], t[1..-1], lv[lk], nk, r)
    end
    defn(:run, String, RequestPart, RequestPartReader) do |k, p, r|
      ks = k.split(".")
      nk = format(ks[0], p.contents)
      run(ks[1], ks[2..-1], p.contents, nk, r)
    end
    defn(:run, Request) { |r| run(@key, r.part(@part), @reader)}

    def from_incoming(part, key, &block)
      @handler.validate_request_part_and_key(part, key)
      r = RequestPartReader.new(@handler.incoming_request_parts[part], key)
      if block_given?
        r.instance_eval(&block)
      end
      @reader = r
    end
  end

  attr_accessor :name, :incoming_request_parts, :outgoing_request, :writers

  defn(:initialize, String, Header, Body, Query) do |n, h, b, q|
    @name = n
    @incoming_request_parts = {header: h, body: b, query: q}
    initialize_outgoing_request
    @writers = []
  end
  defn(:request_part_keys) { [:header, :body, :query] }
  defn(:validate_request_part_and_key, Symbol, String) do |s, k|
    unless Request::PART_KEYS.include?(s)
      raise ArgumentError, "Expected params [(:header, :body, :query), String]"
    end
  end

  defn(:initialize_outgoing_request) do
    @outgoing_request = Request.new(
      Header.new({}),
      Body.new({}),
      Query.new({}))
  end

  defn(:output) do
    initialize_outgoing_request
    @writers.each { |w| w.run(@outgoing_request) }
    @outgoing_request.parts.map { |k, v| v.contents.to_s }
  end

  defn(:guard, Proc) { |p| @guard = p }

  defn(:from, Symbol, String) { |part, key| RequestPartReader.new(@incoming_request_parts[part], key) }
    .when { |part, key| @incoming_request_parts[part] }

  defn(:set, Symbol, String, RequestPartReader) do |part, key, reader|
    RequestPartWriter.new(@outgoing_request[part], key, reader).run
  end.when { |part, key, reader| @outgoing_request[part] }


  def set_outgoing(part, key, &block)
    validate_request_part_and_key(part, key)
    w = RequestPartWriter.new(part, key, self)
    if block_given?
      w.instance_eval(&block)
    end
    @writers << w
  end

  def put_incoming(part, key, &block)
    validate_request_part_and_key(part, key)
    r = RequestPartReader.new(@incoming_request_parts[part], key, self)
    if block_given?
      r.instance_eval(&block)
    end
  end
end