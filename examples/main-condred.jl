
using Jlsca.Sca
using Jlsca.Trs
using Jlsca.Align

# our vanilla  main function
function gofaster()
  if length(ARGS) < 1
    @printf("no input trace\n")
    return
  end

  filename = ARGS[1]
  direction::Direction = (length(ARGS) > 1 && ARGS[2] == "BACKWARD" ? BACKWARD : FORWARD)
  params = getParameters(filename, direction)
  if params == nothing
    params = AesSboxAttack()
  end

  if isa(params, AesMCAttack)
    params.analysis.leakageFunctions = [x -> (x .>> i) & 1 for i in 0:31]
  else
    if isa(params, AesSboxAttack)
      params.analysis.leakageFunctions = [x -> (x .>> i) & 1 for i in 0:7]
    elseif isa(params, DesSboxAttack)
      params.analysis.leakageFunctions = [x -> (x .>> i) & 1 for i in 0:3]
    end
  end

  numberOfAverages = length(params.keyByteOffsets)
  numberOfCandidates = getNumberOfCandidates(params)

  localtrs = InspectorTrace(filename, true)
  addSamplePass(localtrs, tobits)

  @everyworker begin
      using Jlsca.Trs
      # the "true" argument will force the sample type to be UInt64, throws an exception if samples are not 8-byte aligned
      trs = InspectorTrace($filename, true)

      # this efficiently converts UInt64 to packed BitVectors
      addSamplePass(trs, tobits)

      setPostProcessor(trs, CondReduce(SplitByData($numberOfAverages, $numberOfCandidates), $localtrs))
      # setPostProcessor(trs, CondReduce(SplitByTracesBlock(), $localtrs))
  end

  numberOfTraces = @fetch length(Main.trs)

  ret = sca(DistributedTrace(), params, 1, numberOfTraces)

  return ret
end

@time gofaster()
