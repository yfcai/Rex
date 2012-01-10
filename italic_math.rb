module RexPrelude

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
          if argv[i - 1] =~ /([[:alpha:]])(\s*)$/ && !hyphen_following
            "\\itAdjustAfterMath #{$1}$#{$2}#{new_mode}"
          else
            # ends in symbol, but has space. needs those.
            argv[i - 1] =~ /\S(\s+)$/ || argv[i - 1] =~ /^(\s+)$/
            "$#{$1}#{new_mode}"
          end
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
          ## forces italic correction before math
          ## apparently needs no correction here
          ## trailing = /([^\s{}\[\]])(\s)*$/
          ## if argv[i - 1] =~ trailing
          ##  argv[i - 1] = argv[i - 1].sub(trailing, $1+'\/'+$2.to_s)
          ## end
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

def italic_math(arg)
  RexPrelude.italic_math(arg)
end


preamble RexPrelude::ITALIC_MATH_ADJUSTMENTS # this is very hard to use
