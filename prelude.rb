# this is run before all other code

class Float
  # prevents scientific notation
  def to_s(decimal_places=8); "%.#{decimal_places}f" % self end
end

module RexPrelude

@@doc_declare = lambda do
  macrone('documentclass', *@@documentclass)
end

@@preamble = [@@doc_declare]
@@preinject = ["\n\\begin{document}"]
@@postamble = ["\n\\end{document}\n"]

@@documentclass = ['article', nil]

def self.package_like name
  ins = "@@#{name}"
  dat = class_variable_set(ins, {})
  @@preamble << (lambda do
    dat.keys.map do |arg|
      macrone(name, arg, dat[arg])
    end.join
  end)
  Object.define_method(name) do |*args|
    dat[args[0]] = args[1]
  end
end

# the third param block receives the strings and format them
def self.theorem_like(name, preceding = nil, counter = nil,
referrer = lambda{|a| a.join('.')},
&definer
)
  counter ||= name
  @@theorem_like_cnt[name] = counter
  @@theorem_like_pre[name] = preceding if preceding
  @@theorem_like_cur[counter] = 0
  Object.define_method(name) do |*args|
    arg, opt = args
    RexPrelude.theorem_like_cur[counter] += 1
    my_id = RexPrelude.theorem_like_trace(name)
    RexPrelude.theorem_like_str[opt] = referrer.call(my_id)
    definer.call(arg, opt, *my_id.reverse)
  end
end
@@theorem_like_cnt = {};
@@theorem_like_str = {}; def self.theorem_like_str; @@theorem_like_str end
@@theorem_like_pre = {}; def self.theorem_like_pre; @@theorem_like_pre end
@@theorem_like_cur = {}; def self.theorem_like_cur; @@theorem_like_cur end
def self.counter; @@theorem_like_cur end
def self.theorem_like_trace(name)
  pre = @@theorem_like_pre[name]
  (pre ? theorem_like_trace(pre) : []) <<
    @@theorem_like_cur[@@theorem_like_cnt[name]]
end

def self.documentclass; @@documentclass end
def self.documentclass=(x); @@documentclass = x end
def self.preamble; @@preamble end
def self.preinject; @@preinject end
def self.postamble; @@postamble end

def self.optional(content, left='[', right=']')
  content ? left + content + right : ''
end

def self.macrone(name, arg, opt=nil)
  "\\" + name + optional(opt) + "{#{arg}}"
end

def self.env(arg, opt, options=nil)
  "\\begin{#{opt}}#{optional options}\n#{arg}\\end{#{opt}}\n"
end

end


################ INTERFACE BELOW ################

# make define_method public lol!
class Class; public :define_method end
def define_method(name, &block); self.class.define_method(name, &block) end

# parse key-value pairs
def keyval(arg)
  hash = {}
  arg.split(',').each do |s|
    k, v = s.split('=')
    hash[k.strip] = v && v.strip
  end
  hash
end

def optional(content, left='[', right=']')
  RexPrelude.optional(content, left, right)
end

# "\\" + name + optional(opt) + "{#{arg}}"
def macrone(name, arg, opt=nil)
  RexPrelude.macrone(name, arg, opt)
end

def documentclass(arg, opt=nil)
  RexPrelude.documentclass = [arg, opt]
  nil
end

def preamble(arg)
  RexPrelude.preamble << arg
  nil
end

def ref(arg)
  lambda do
    RexPrelude.theorem_like_str[arg] ||
    "[UNRESOLVED REFERENCE #{arg}]"
  end # creates suspension!
end

RexPrelude.package_like('usepackage')
RexPrelude.package_like('usetikzlibrary')

def tikzlibrary(arg, opt=nil)
  usepackage('tikz')
  usetikzlibrary(arg, opt)
end

RexPrelude.theorem_like('section') do |arg, opt, num|
  "\\setcounter{section}{#{num - 1}}" +
    macrone('section', arg)
end

# "\\begin{#{opt}}#{optional options}\n#{arg}\\end{#{opt}}\n"
def env(arg, opt=nil, options=nil); RexPrelude.env(arg, opt, options) end

def newtheorem(name, print = nil, new = nil)
  print ||= name.capitalize
  preamble(new ? "\\newtheorem{#{name}}{#{print}}[section]\n" :
           "\\newtheorem{#{name}}[theorem]{#{print}}\n")
  RexPrelude.theorem_like(name, 'section', 'theorem') do |arg, opt, num, sec|
    "\\setcounter{theorem}{#{num - 1}}\\setcounter{section}{#{sec}}" +
      RexPrelude.env(arg, name, nil) # must preprocess arg to get opt
  end
  preamble "\\newtheorem*{#{name}?}{#{print}}\n"
  define_method(name + '?') do |*args|
    arg, opt = args
    RexPrelude.env(arg, name + '?', opt)
  end
end

def counter(arg)
  RexPrelude.counter[arg]
end

def setcounter(arg, opt)
  RexPrelude.counter[opt] = arg.to_i
  nil
end

# "tikzfig[label]{caption}
# label is required because we automatically mkdir & touch stuff for you!
def tikzfig(arg, opt)
  label, scale, options = opt.split('#')
  scale ||= 1
  usepackage "pdfpages"
  usepackage "float" if options.to_s.include? 'H'
  path = "fig/#{label}/"
  file = path + 't.rex'
  rslt = path + 't.pdf'
  unless File.exist?(file)
    start_content = %{\
\\def\\par{} % the whole figure is one giant paragraph
% tikz figure #{label}
"documentclass{standalone}
"usepackage{tikz}
\\begin{tikzpicture}

\\end{tikzpicture}
}
    `mkdir -p #{path}`
    unless $?.success?
      $stderr.puts "!!!! Tikzfigure #{file} creation failed. !!!!"
      exit 1
    else
      File.open(file, 'w'){|f| f.write(start_content)}
    end
  end
  unless File.exist?(rslt) && File::mtime(rslt) > File::mtime(file)
    output = `cd #{path} 2>&1 && pdflatex t.rex 2>&1`
    unless $?.success?
      $stderr.puts output
      $stderr.puts "!!!! Figure #{file} failed to compile. !!!!"
      exit 1
    end
    output = nil
  end
  tikzfig_counter(nil, label)
  RexPrelude.env %{
    \\centering
    #{RexPrelude.macrone('includegraphics', rslt, "scale=#{scale}")}
    #{RexPrelude.macrone('caption', arg)}
  }, "figure", options
end
RexPrelude.theorem_like('tikzfig_counter') do nil end



################ CUSTOM SETTINGS ################

usepackage 'amsmath'
usepackage 'amssymb'
usepackage 'amsthm'

# newtheorem depends on these preambles
preamble "\\swapnumbers\\theoremstyle{definition}\n"
newtheorem('theorem', nil, true)

%w[definition lemma corollary].each {|name| newtheorem(name)}

# large environments such as proof must come after complete recursivity
