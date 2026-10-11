# Real native framebuffer: unchanged layout outside the eye aperture.
# Usage: ruby simulator/robot_home_spacing_test.rb PREVIEW_EXECUTABLE
require 'tmpdir'
preview = File.expand_path(ARGV.fetch(0))
Dir.mktmpdir('robot-spacing-', '/private/tmp') do |dir|
  %w[home home-optimus home-megatron home-starscream].each do |scene|
    frames = ['', '-half', '-blink'].map do |suffix|
      path = File.join(dir, scene + suffix + '.ppm')
      abort 'render failed' unless system(preview, path, scene + suffix, out: File::NULL)
      raw = File.binread(path)
      header = "P6\n466 466\n255\n"
      abort 'unexpected framebuffer' unless raw.start_with?(header)
      raw.byteslice(header.bytesize..).bytes
    end
    # Render both sides of every animation boundary, not just static fixtures.
    # This includes open gaps, completion, and the absence of a fourth blink.
    [0, 69, 70, 229, 230, 359, 360, 479, 480, 549, 550, 709, 710,
     839, 840, 959, 960, 1029, 1030, 1189, 1190, 1319, 1320, 1439,
     1440, 1800].each do |elapsed|
      path = File.join(dir, "#{scene}-#{elapsed}.ppm")
      abort 'timed render failed' unless system(preview, path, scene + '-blink', elapsed.to_s, out: File::NULL)
      raw = File.binread(path)
      header = "P6\n466 466\n255\n"
      abort 'unexpected timed framebuffer' unless raw.start_with?(header)
      frame = raw.byteslice(header.bytesize..).bytes
      phase = elapsed % 480
      expected = elapsed >= 1320 || phase >= 360 ? 0 : (phase < 70 || phase >= 230 ? 1 : 2)
      abort "#{scene}: wrong blink frame at #{elapsed}ms" unless frame == frames[expected]
    end
    frames.drop(1).each do |frame|
      changes = (0...466*466).select { |p| frames[0][p*3,3] != frame[p*3,3] }
      abort "#{scene}: no blink" if changes.empty?
      # Eye JPEG blocks are around source y=140..180, rendered y=218..273.
      # Permit JPEG 8px block spill, but forbid mouth/status/battery movement.
      abort "#{scene}: changes outside eyes" unless changes.all? { |p| (205..282).cover?(p/466) && (160..310).cover?(p%466) }
    end
    idle = frames[0]
    bounds = [[30,52],[54,407],[409,440]].map do |lo,hi|
      visible = (lo..hi).flat_map { |y| (0...466).map { |x| [x,y] if idle[(y*466+x)*3,3].max > 70 }.compact }
      abort "#{scene}: missing component" if visible.empty?
      [visible.map(&:first).minmax,visible.map(&:last).minmax]
    end
    status,portrait,battery=bounds
    abort "#{scene}: no clearance" unless portrait[1][0]-status[1][1]>10 && battery[1][0]-portrait[1][1]>10
    [status,battery].each { |b| abort "#{scene}: status/battery off center" unless ((b[0][0]+b[0][1])/2.0-233).abs <= 1 }
    puts "PASS #{scene}: eye-only native blink, stable geometry, clear status/battery"
  end
end
