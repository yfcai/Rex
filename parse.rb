# it is much better to freeze s before proceeding.

# ISSUE
# For some reason, last char of a file does not appear in generated tex.
# It forces me to put \n at end of file for the moment.

module RexParse

def self.wedge_char_plus(s, j, hash, preserve = nil)
  rslt = case for i in j...s.length do
     (handler = hash[s[i]]) && (break handler) end
  when Proc
    handler.call(s, i)
  when Symbol
    send(handler, s, i)
  else
    []
  end
  if i==nil || j==nil
   puts j.inspect
   puts i.inspect
   puts s[j..j+10];throw :Exception
  end
  j < i ? rslt << s[j...i] : preserve ? rslt << nil : rslt
end

def self.matched_chars(s, j, open, close, escape = 92) # '\\'[0] == 92
  return [nil, j] if s[j] != open
  i, depth = j + 1, 0
  while i < s.length do
    case s[i]
    when escape;i     += 1 # skip next char
    when open  ;depth += 1
    when close ;depth -= 1
    end
    break if depth < 0
    i += 1
  end
  [s[j + 1 ... i], i + 1]
end

def self.parse(s)
  parse_tex(s, 0)
end

def self.parse_tex(s, i)
  return [] if i >= s.length
  # 34 == '"'[0]
  wedge_char_plus(s, i, {34 => :parse_rex})
end

def self.parse_rex(s, i)
  if i >= 1 && s[i - 1] == 92 # '\\'[0] == 92
    parse_tex(s, i + 1) << '"'
  else
    parse_tag(s, i+1)
  end
end

def self.parse_tag(s, i)
  # 91 == '['[0], 123 == '{'[0]
  rslt = wedge_char_plus(s, i, {91 => :parse_opt, 123 => :parse_opt}, true)
  tag, opt, arg = (1..3).map{(x = rslt.pop) && x.strip}
  rslt << execute(tag, opt, arg)
end

def self.parse_opt(s, i)
  # [91, 93] == ['['[0], ']'[0]]
  t, j = matched_chars(s, i, 91, 93)
  parse_arg(s, j) << t
end

def self.parse_arg(s, i)
  # eat up space between [opt] and {arg}
  # [123, 125] == ['{'[0], '}'[0]]
  i += s[i..-1] =~ (/\S/)
  t, j = matched_chars(s, i, 123, 125)
  parse_tex(s, j) << t
end

@@execute = []
def self.executed; @@execute end
def self.execute(tag, opt, arg)
  @@execute <<
    if tag
      opt ? "#{tag}(#{arg.inspect},#{opt.inspect})" :
        "#{tag}(#{arg.inspect})"
    else arg end
  t = @@execute.length - 1
  lambda{@@execute[t]}
end

end
