# Decode actual cached native frames; effects/pose may change only portrait rows.
require 'tmpdir'
preview=File.expand_path(ARGV.fetch(0))
Dir.mktmpdir('hero-spacing-','/private/tmp') do |dir|
  abort 'sequence render failed' unless system(preview,'--home-sequence',dir)
  header="P6\n466 466\n255\n"
  %w[bumblebee bumblebeefullbody optimus jazz hotrod wheeljack hound ironhide ratchet].each do |hero|
    frames=(0...54).map do |i|
      raw=File.binread(File.join(dir,format('%s-%03d.ppm',hero,i)))
      abort 'unexpected framebuffer' unless raw.start_with?(header)
      raw.byteslice(header.bytesize..)
    end
    idle=frames[0]
    [12,14,15,19,23,27].each do |i|
      abort "#{hero}: no immediate frame #{i}" if idle==frames[i]
    end
    frames.each_with_index do |frame,i|
      # Status and battery pixels must stay identical through every phase.
      abort "#{hero}: status changed in #{i}" unless idle.byteslice(0,64*466*3)==frame.byteslice(0,64*466*3)
      abort "#{hero}: battery changed in #{i}" unless idle.byteslice(399*466*3..)==frame.byteslice(399*466*3..)
    end
    (33...54).each { |i| abort "#{hero}: did not return to idle" unless idle==frames[i] }
    bounds=[[30,52],[64,398],[409,440]].map do |lo,hi|
      points=[]
      (lo..hi).each { |y|(0...466).each { |x| points<<[x,y] if idle.byteslice((y*466+x)*3,3).bytes.max>70 } }
      abort "#{hero}: missing component" if points.empty?
      [points.map(&:first).minmax,points.map(&:last).minmax]
    end
    status,portrait,battery=bounds
    abort "#{hero}: no clearance" unless portrait[1][0]-status[1][1]>10&&battery[1][0]-portrait[1][1]>10
    [status,battery].each { |b|abort "#{hero}: off center" unless ((b[0][0]+b[0][1])/2.0-233).abs<=1 }
    puts "PASS #{hero}: immediate press/skill, clear status/battery, final idle pixels"
  end
end
