# Pixel-level geometry test against the real M5GFX renderer.
# Usage: ruby simulator/robot_home_spacing_test.rb PREVIEW_EXECUTABLE
require 'tmpdir'
preview = File.expand_path(ARGV.fetch(0))
Dir.mktmpdir('robot-spacing-', '/private/tmp') do |dir|
  %w[home home-optimus home-megatron home-starscream home-talking home-optimus-talking home-megatron-talking home-starscream-talking].each do |scene|
    path = File.join(dir, scene + '.ppm')
    abort 'render failed' unless system(preview, path, scene, out: File::NULL)
    raw = File.binread(path)
    header = "P6\n466 466\n255\n"
    abort 'unexpected framebuffer' unless raw.start_with?(header)
    pixels = raw.byteslice(header.bytesize..).bytes
    bounds = [[30, 52, false], [54, 407, true], [409, 440, false]].map do |lo, hi, saturated|
      xs = []; ys = []
      (lo..hi).each do |y|
        (0...466).each do |x|
          rgb = pixels[(y * 466 + x) * 3, 3]
          next unless rgb.max > 70 && (!saturated || rgb.max - rgb.min > 40)
          xs << x; ys << y
        end
      end
      abort "#{scene}: missing visible component" if xs.empty?
      [xs.min, xs.max, ys.min, ys.max]
    end
    status, ring, battery = bounds
    upper_gap = ring[2] - status[3] - 1
    lower_gap = battery[2] - ring[3] - 1
    abort "#{scene}: unequal gaps #{upper_gap}/#{lower_gap}" unless (upper_gap - lower_gap).abs <= 1
    bounds.each do |left, right, _top, _bottom|
      abort "#{scene}: off-center component" unless ((left + right) / 2.0 - 233).abs <= 1
    end
    abort "#{scene}: insufficient clearance" unless [upper_gap, lower_gap].min >= 10
    puts "PASS #{scene}: centered components, gaps #{upper_gap}/#{lower_gap}"
  end
end
