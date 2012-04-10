#!/usr/bin/ruby
# this is actually Rex.

module RexExec

  EXTREX = 'rex'
  EXTTEX = 'tex'

  LIBPATH = ENV['HOME'] + '/sc/LMb.rex'

  PDFLATE = 'remotex -interaction=nonstopmode "\input"'
  TINPUTS = '.:' + ENV['HOME'] + '/sc/AAA:'

  TRAIN   = /\.#{EXTREX}$/i
  FILENAMES = ARGV.select {|x| x =~ TRAIN}

  INFILE  = FILENAMES.first
  TEXFILE = FILENAMES.first.sub(TRAIN, ".#{EXTTEX}")
  TEXHAND = File.open(TEXFILE,'w')

  def self.evaluate(p)
    p = p.call while p.class == Proc; p
  end

  def self.body; @@body end
  def self.body=(b); @@body = b end

end

if RexExec::FILENAMES.length != 1
  $stderr.puts "rex: incorrect usage.\n" +
    "    ARGS = #{ARGV.join ' '}"
  exit 1
end

['parse', 'prelude'].each do |file|
  load("#{RexExec::LIBPATH}/#{file}.rb")
end

source = File.open(RexExec::INFILE).read.freeze

first_line = source.split("\n",2).first
case first_line
when /latex/i
  exec %{export TEXINPUTS=#{RexExec::TINPUTS} && \
  #{RexExec::PDFLATE} #{RexExec::INFILE}
}
end if first_line[0] == 37 # '%'

RexExec.body = RexParse.parse(source)

environment = lambda{}.binding
(RexParse.executed.length - 1).downto(0) do |i|
  RexParse.executed[i] = eval(RexParse.executed[i], environment)
end

RexPrelude.preamble.each{|s|
RexExec::TEXHAND.write(RexExec.evaluate(s))}
RexPrelude.preinject.each{|s|
RexExec::TEXHAND.write(RexExec.evaluate(s))}
RexExec.body.reverse_each{|s|
RexExec::TEXHAND.write(RexExec.evaluate(s))}
RexPrelude.postamble.reverse_each{|s|
RexExec::TEXHAND.write(RexExec.evaluate(s))}

RexExec::TEXHAND.close

exec %{\
export TEXINPUTS=#{RexExec::TINPUTS} && \
#{RexExec::PDFLATE} #{RexExec::TEXFILE}
}
