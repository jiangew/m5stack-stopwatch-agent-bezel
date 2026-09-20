# Convert two approved mono 24 kHz / signed 16-bit WAV auditions to flash data.
# Usage: ruby scripts/embed_robot_speech.rb TASK.wav LAUGH.wav include/RobotSpeechLocal.h
abort 'expected TASK.wav LAUGH.wav OUTPUT.h' unless ARGV.size == 3
def samples(path)
  wav = File.binread(path)
  abort 'not RIFF WAVE' unless wav[0,4]=='RIFF' && wav[8,4]=='WAVE'
  offset=12;fmt=nil;pcm=nil
  while offset+8<=wav.bytesize
    kind=wav[offset,4];size=wav[offset+4,4].unpack1('V')
    chunk=wav[offset+8,size]
    abort 'truncated WAV' unless chunk && chunk.bytesize==size
    fmt=chunk if kind=='fmt ';pcm=chunk if kind=='data'
    offset+=8+size+(size%2)
  end
  abort 'expected mono 24k PCM16' unless fmt && fmt.unpack('vvVVvv')==[1,1,24000,48000,2,16]
  abort 'invalid duration' unless pcm && pcm.bytesize.even? && pcm.bytesize.between?(4800,240000)
  pcm.unpack('s<*')
end
clips=[samples(ARGV[0]),samples(ARGV[1])]
text="// Private user-supplied audio. Do not publish without distribution rights.\n#pragma once\n#include <cstddef>\n#include <cstdint>\nnamespace robot_speech {\ninline constexpr bool kAvailable = true;\nconstexpr std::uint32_t kSampleRate = 24000;\n"
%w[Task Laugh].zip(clips).each do |name,pcm|
  text+="inline constexpr std::int16_t k#{name}[] = {\n"
  pcm.each_slice(16){|row|text+='  '+row.join(',')+",\n"}
  text+="};\n"
end
text+="}  // namespace robot_speech\n"
File.write(ARGV[2],text)
