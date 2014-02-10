# unit-test-all.sh
# run all unit tests

luajit allZero_test.lua
luajit argmax_test.lua
luajit asColumnMatrix_test.lua
luajit asFactor_test.lua
luajit assertEq_test.lua
luajit augment_test.lua

luajit bestApns_test.lua
luajit bytesIn_test.lua

luajit CacheFile_test.lua
luajit center_test.lua
luajit checkGradient_test
luajit CommandLine_test.lua
luajit concatHorizontal_test.lua
luajit ConfusionMatrix_test.lua

luajit Dataframe_test.lua
luajit directoryAssureExists_test.lua
luajit directoryAssureNotExists_test.lua
luajit directoryDelete_test.lua
luajit directoryExists_test.lua
luajit distancesEuclidean_test.lua
luajit distancesSurface2_test.lua

luajit equalObjectValues_test.lua
luajit equalTensors_test.lua
luajit extract_test.lua
luajit extractTensor_test.lua

luajit fileAssureExists_test.lua
luajit fileAssureNotExists_test.lua
luajit fileDelete_test.lua
luajit fileExists_test.lua
luajit finiteDifferenceGradient_test.lua

luajit hasNA_test.lua
luajit hasNaN_test.lua
luajit head_test.lua

luajit ifelse_test.lua
luajit imputeissingFeature_test.lua
luajit isnan_test.lua
luajit isSequence_test.lua
luajit isTensor_test.lua

luajit kernelEpanechnikovQuadraticKnn_test.lua
luajit keyboard_test.lua
luajit keys_test.lua
luajit kroneckerProduct.lua 

luajit makeDistanceSurface_test.lua
luajit makeLogreg_test.lua
luajit makeNextNonZeroImportanceIndex_test.lua
luajit makeNextPermutedIndex_test.lua
luajit makeSampler_test.lua
luajit makeSampleIndexer_test.lua
luajit maxIndex_test.lua
luajit memoizedComputationOnDisk_test.lua
luajit memoryUsed_test.lua
luajit metersPerLatitudeDegree_test.lua
luajit metersPerLongitudeDegree_test.lua
luajit ModelLinearL2Loss_test.lua
luajit ModelLogisticRegression_OLD_test.lua
luajit ModelLogreg01_test.lua
luajit ModelLogregNnbatch_test.lua
luajit ModelLogregOLD_test.lua
luajit ModelLogreg_test.lua

luajit NamedMatrix_test.lua

luajit ObjectivefunctionLogregMurphybatch_test.lua
luajit ObjectivefunctionLogregNnbatch_test.lua
luajit ObjectivefunctionLogregNnone_test.lua
luajit ObjectivefunctionLogreg_test.lua
luajit Objectivefunction_test.lua
luajit optim_gd_test.lua
luajit optim_vsgfd_test.lua

luajit parseCommandLine_test.lua
luajit printAllVariables_test.lua
luajit printTableValueOLD_test.lua
luajit printTableValue_test.lua
luajit printTableVariable_test.lua
luajit printVariable_test.lua

luajit Random_test.lua

luajit Sequence2String_test.lua
luajit sequenceContains_test.lua
luajit sgdBottou_test.lua
luajit sigmoid_tet.lua
luajit SliceReader_test.lua
luajit softmaxes_test.lua
luajit splitString_test.lua
luajit splitTensor_test.lua
luajit StackFrame_test.lua
luajit standardize_test.lua
luajit stop_test.lua

luajit TableCached_test.lua
luajit Timer_test.lua
luajit time_test.lua

luajit unique_test.lua

luajit validateAttributes_test.lua
luajit validate_test.lua
luajit view1DAs2D_test.lua
luajit variableValue_test.lua
luajit viewAdditionalRows_test.lua
luajit viewAsColumnVector_test.lua

echo "ALL UNIT TESTS COMPLETED"


