# unit-test-all.sh
# run all unit tests

torch allZero_test.lua
torch argmax_test.lua
torch asColumnMatrix_test.lua
torch asFactor_test.lua
torch assertEq_test.lua
torch augment_test.lua

torch bestApns_test.lua
torch bytesIn_test.lua

torch CacheFile_test.lua
torch center_test.lua
luajit checkGradient_test
torch CommandLine_test.lua
torch concatHorizontal_test.lua
luajit ConfusionMatrix_test.lua

torch Dataframe_test.lua
torch directoryAssureExists_test.lua
torch directoryAssureNotExists_test.lua
torch directoryDelete_test.lua
torch directoryExists_test.lua
luajit distancesEuclidean_test.lua
torch distancesSurface2_test.lua

torch equalObjectValues_test.lua
torch equalTensors_test.lua
torch extract_test.lua
torch extractTensor_test.lua

torch fileAssureExists_test.lua
torch fileAssureNotExists_test.lua
torch fileDelete_test.lua
torch fileExists_test.lua
luajit finiteDifferenceGradient_test.lua

torch hasNA_test.lua
torch hasNaN_test.lua
torch head_test.lua

torch ifelse_test.lua
luajit imputeissingFeature_test.lua
torch isnan_test.lua
torch isSequence_test.lua
luajit isTensor_test.lua

torch kernelEpanechnikovQuadraticKnn_test.lua
torch keyboard_test.lua
torch keys_test.lua
luajit kroneckerProduct.lua 

torch makeDistanceSurface_test.lua
torch makeLogreg_test.lua
torch makeNextNonZeroImportanceIndex_test.lua
torch makeNextPermutedIndex_test.lua
torch makeSampler_test.lua
torch makeSampleIndexer_test.lua
torch maxIndex_test.lua
torch memoizedComputationOnDisk_test.lua
torch memoryUsed_test.lua
torch metersPerLatitudeDegree_test.lua
torch metersPerLongitudeDegree_test.lua
torch ModelLinearL2Loss_test.lua
luajit ModelLogisticRegression_OLD_test.lua
luajit ModelLogreg01_test.lua
luajit ModelLogregNnbatch_test.lua
luajit ModelLogregOLD_test.lua
luajit ModelLogreg_test.lua

torch NamedMatrix_test.lua

luajit ObjectivefunctionLogregMurphybatch_test.lua
luajit ObjectivefunctionLogregNnbatch_test.lua
luajit ObjectivefunctionLogregNnone_test.lua
luajit ObjectivefunctionLogreg_test.lua
luajit Objectivefunction_test.lua
luajit optim_gd_test.lua
luajit optim_vsgfd_test.lua

torch parseCommandLine_test.lua
luajit printAllVariables_test.lua
luajit printTableValueOLD_test.lua
luajit printTableValue_test.lua
luajit printTableVariable_test.lua
luajit printVariable_test.lua

luajit Random_test.lua

luajit Sequence2String_test.lua
torch sequenceContains_test.lua
torch sgdBottou_test.lua
luajit sigmoid_tet.lua
torch SliceReader_test.lua
torch softmaxes_test.lua
luajit splitString_test.lua
torch splitTensor_test.lua
luajit StackFrame_test.lua
torch standardize_test.lua
torch stop_test.lua

torch TableCached_test.lua
torch Timer_test.lua
luajit time_test.lua

torch unique_test.lua

torch validateAttributes_test.lua
luajit validate_test.lua
torch view1DAs2D_test.lua
luajit variableValue_test.lua
torch viewAdditionalRows_test.lua
torch viewAsColumnVector_test.lua

echo "ALL UNIT TESTS COMPLETED"


