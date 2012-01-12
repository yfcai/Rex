# this is run before all other code

class Float
  # prevents scientific notation
  def to_s(decimal_places=8); "%.#{decimal_places}f" % self end
end

################ RexPrelude HERE ################

module RexPrelude

@@doc_declare = lambda do
  macrone('documentclass', *@@documentclass) + "\n"
end

@@preamble = [@@doc_declare]
@@preinject = ["\n\\begin{document}\n"]
@@postamble = ["\n\\end{document}\n"]

@@documentclass = ['article', nil]

def self.package_like name
  ins = "@@#{name}"
  dat = class_variable_set(ins, {})
  @@preamble << (lambda do
    dat.keys.map do |arg|
      macrone(name, arg, dat[arg]) + "\n"
    end.join
  end)
  Object.define_method(name) do |*args|
    dat[args[0]] = args[1]
  end
end

# the third param block receives the strings and format them
def self.theorem_like(
name,
preceding   = nil,
counter     = nil,
referrer    = lambda{|a| a.join('.')},
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
  nil
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

end # RexPrelude

################ RexPrelude ENDS ################
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

# TODO: REDEFINE TITLE & AUTHOR
# SO THAT TITLE IS PLACED AT THE PLACE OF INVOCATION
#def title arg; macrone 'title', arg end
#def author arg; macrone 'author', arg end

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
  setcounter(0, 'theorem') # reset theorem counter.
  "\\setcounter{section}{#{num - 1}}" +
    macrone('section', arg)
end

# "\\begin{#{opt}}#{optional options}\n#{arg}\\end{#{opt}}\n"
def env(arg, opt=nil, options=nil); RexPrelude.env(arg, opt, options) end

@newtheorem_statements = {}
def restate(label)
  @newtheorem_statements[label]
end
def newtheorem(name, opt = {})
  o = {
    :new    => true,
    :swap   => true,
    :parent => nil,
    :print  => name.capitalize,
  }.merge(opt)
  new    = o[:new]
  swap   = o[:swap]
  parent = o[:parent]
  print  = o[:print]
  declaration  = swap ? "\\swapnumbers\n" : ''
  declaration += "\\theoremstyle{definition}\n"
  preamble declaration
  if new # some nasty semantics here
    counter = nil
    precurs = parent
  else
    counter = parent
    precurs = nil
  end
  preamble "\\newtheorem{#{name}}#{RexPrelude.optional counter}{#{
    print}}#{RexPrelude.optional precurs}\n"
  preamble "\\newtheorem*{#{name}?}{#{print}}\n"
  preamble "\\swapnumbers\n" if swap
  # this is a nasty hack that won't work if pushed
  counter ||= name
  precurs = 'section' unless new
  RexPrelude.theorem_like(name, precurs, counter) do
    |arg, opt, num, sec|
    #"\\setcounter{theorem}{#{num - 1}}\\setcounter{section}{#{sec}}" +
    @newtheorem_statements[opt] = "\\setcounter{#{counter}}{#{num - 1}}" +
      (precurs && "\\setcounter{#{precurs}}{#{sec}}").to_s +
      RexPrelude.env(arg, name, nil) # must preprocess arg to get opt
  end
  define_method(name + '?') do |*args|
    arg, opt = args
    RexPrelude.env(arg, name + '?', opt)
  end
  nil
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
  tikzfig_counter(nil, label) if arg.length > 0
  RexPrelude.env %{
    \\centering
    #{RexPrelude.macrone('includegraphics', rslt, "scale=#{scale}")}
    #{arg.length > 0 ? RexPrelude.macrone('caption', arg) : nil}
  }, "figure", options
end
# tikzfig_counter assumes that the document has only tikz figures.
# might as well rename tikzfig to figure.
# the 'false' parameter indicates that it should not be typeset
# with italic_math module.
RexPrelude.theorem_like('tikzfig_counter') do end

# problem
preamble '
\newdimen\pproblsep \pproblsep=5pt
\newdimen\pprobskip \pprobskip=30pt
\newdimen\pprobhead \pprobhead=60pt
\newdimen\pprobwidth \pprobwidth=\dimexpr\hsize-2\pprobskip-\pprobhead
'
def problem(arg)
  skip = '\smallbreak'
  cr = "\\cr\n"
  lines = arg.split("#").map{|s|s.strip}
  skip + '{\def\\\\{\hfil\break}
\halign{\hskip\pprobskip\hbox
to\pprobhead{\it#\hfil}&
\vtop spread\pproblsep{\hsize=\pprobwidth\parindent0pt
#
\par\vfil}\cr
' +
    'Problem&	' + lines[0] + cr +
    'Instance&	' + lines[1] + cr +
    (lines[3] && 'Parameter&	' + lines[2] + cr).to_s +
#    "\\noalign{\\pproblsep=0pt}\n" +
    'Question&	' + lines.last + "\\cr\n}}" + skip + "\n"
end


################ CUSTOM SETTINGS ################

usepackage 'amsmath'
usepackage 'amssymb'
usepackage 'amsthm'

preamble "\\input defs\n"

# newtheorem depends on these preambles
newtheorem('theorem', :parent => 'section')

%w[definition lemma corollary remark observation].each do |name|
  newtheorem(name, :new => false, :parent => 'theorem')
end

# large environments such as proof must come after complete recursivity
