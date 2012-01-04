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
@@preinject = ["\\begin{document}\n"]
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
italic_math = true,
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
    arg = RexPrelude.italic_math(arg) if italic_math
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

# Typeset interspersed italic text & math.
# Assumes the containing environment is italic.
#
=begin Examples

"italic_math{If \m U \it or \m V \it and \m X\it, and}

"italic_math{
  Quarantined \m H\sc-free edge deletion \it is
  incompressible if \m H\it is \m3\it-connected
  and incomplete.
}

=end
def self.italic_math(arg)
  argv = arg.split(ITALIC_MATH_REGEX)
  last_nonmath =
    prev = ITALIC_MATH_ITALICS.first # require IT..CS. to be '\it'
  1.step(argv.length - 1, 2) do |i|
    belo = argv[i]
    if belo == '$' # replace dollar sign with stuff
      case prev
      when ITALIC_MATH_BEGIN # exiting math mode
        belo = last_nonmath
        # must deal with space-eating macros
        argv[i - 1] += $1 if argv[i + 1] =~ /^(\s+)/
      else # entering math mode
        belo = ITALIC_MATH_BEGIN
      end
    end
    if prev == ITALIC_MATH_BEGIN
      # exiting math mode
      new_mode = belo # spacing issues if saved
      argv[i] =
        case belo
        when ITALIC_MATH_BEGIN
          $stderr.puts('Invalid use of RexPrelude::italic_math: '+
                       'entering math mode from math mode.');throw(arg)
        when *ITALIC_MATH_ITALICS
          # exiting math into italics; discarding implicit italic correction.
          #
          # ISSUE: too complicated to parse entire math list.
          #   we assume, stupidly, that any trailing nonalphabetic character
          #   is a symbol and needs no adjustment.
          #
          hyphen_following = (argv[i+1] =~ /^\s*-/) &&
            !(argv[i - 1] =~ /\s$/)
          argv[i - 1] =~ /([[:alpha:]])(\s*)$/ && !hyphen_following ?
          "\\itAdjustAfterMath #{$1}$#{$2}#{new_mode}" : "$#{$2}#{new_mode}"
        else
          # exiting math into roman; implicit italic correction is correct.
          argv[i - 1] =~ /(\s*)$/
          "$#{$1}#{new_mode}"
        end
    elsif belo == ITALIC_MATH_BEGIN
      # entering math mode
      argv[i] =
        case prev
        when *ITALIC_MATH_ITALICS
          # entering math mode from italics
          # makes stupid assumption; see ISSUE above.
          argv[i + 1] =~ /^\s*([[:alpha:]])/ ?
          "$\\itAdjustBeforeMath #{$1}" : '$'
        else
          # entering math from roman
          '$'
        end
    elsif ITALIC_MATH_ITALICS.include?(prev) &&
        ITALIC_MATH_ROMANS.include?(belo)
      # entering roman from italics; should get corrected.
      lettre, spaces = argv[i - 1].split(/(\s*)$/)
      if lettre.to_s.length > 0
        argv[i - 1] = "#{lettre}\\/#{spaces}"
      else # lettre.length == 0: give it up. too late to worry now.
      end
    end
    prev = belo
    last_nonmath = belo if belo != ITALIC_MATH_BEGIN
  end
  argv.join
end
ITALIC_MATH_ITALICS = # the first one must be an incarnation of \it.
%w[\\it \\sl]
ITALIC_MATH_ROMANS =
%w[\\bf \\sc \\sf \\rm \\tt]
ITALIC_MATH_BEGIN =
"\\m"
ITALIC_MATH_REGEX = Regexp.new(
'(\$)|(?:('+
[ITALIC_MATH_ITALICS,ITALIC_MATH_ROMANS,ITALIC_MATH_BEGIN].flatten.map{|s|
"\\"+s}.join('|')+')(?![[:alpha:]]))')
ITALIC_MATH_ADJUSTMENTS =
%q[\newlength\itMathAdjustmentOne
\newlength\itMathAdjustmentTwo
\def\itAdjustBeforeMath#1{%
\settowidth\itMathAdjustmentOne{#1\/}%
\settowidth\itMathAdjustmentTwo{$#1$}%
\addtolength\itMathAdjustmentOne{-\itMathAdjustmentTwo}%
\hspace{\itMathAdjustmentOne}}
\def\itAdjustAfterMath#1{%
\settowidth\itMathAdjustmentOne{#1\/}%
\settowidth\itMathAdjustmentTwo{#1}%
\addtolength\itMathAdjustmentOne{-\itMathAdjustmentTwo}%
\hspace{-\itMathAdjustmentOne}}
]

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

# ISSUE: no support for roman theorem text.
# Roman text requires two things:
# 1. Call theorem_like with italic_math set to false.
# 2. Ensure \theoremstyle{definition} before \newtheorem.
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

def italic_math(arg)
  RexPrelude.italic_math(arg)
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
# tikzfig_counter assumes that the document has only tikz figures.
# might as well rename tikzfig to figure.
# the 'false' parameter indicates that it should not be typeset
# with italic_math module.
RexPrelude.theorem_like('tikzfig_counter',nil,nil,false) do nil end


################ CUSTOM SETTINGS ################

usepackage 'amsmath'
usepackage 'amssymb'
usepackage 'amsthm'

# newtheorem depends on these preambles
preamble "\\swapnumbers\n"
preamble RexPrelude::ITALIC_MATH_ADJUSTMENTS
newtheorem('theorem', nil, true)

%w[definition lemma corollary].each {|name| newtheorem(name)}

# large environments such as proof must come after complete recursivity
