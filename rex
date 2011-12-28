#!/usr/bin/ruby
# this is actually Rex.

module RexExec

  EXTREX = 'rex'
  EXTTEX = 'tex'

  LIBPATH = ENV['HOME'] + '/sc/LMb.rex'

  PDFLATE = 'remotex -interaction=nonstopmode "\input"'
  TINPUTS = '.:' + ENV['HOME'] + '/sc/AAA:'

  FILENAMES = ARGV.select {|x| x =~ /\.#{EXTREX}$/i}

  INFILE  = FILENAMES.first
  TEXFILE = INFILE.sub(/\.#{EXTREX}$/i, ".#{EXTTEX}")
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

RexExec.body = RexParse.parse(File.open(RexExec::INFILE).read.freeze)

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
export       TEXINPUTS=#{RexExec::TINPUTS} && \
#{RexExec::PDFLATE} #{RexExec::TEXFILE}
}
