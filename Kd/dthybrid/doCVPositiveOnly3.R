

# inMat <- rbind(c(0, 1, 1, 0, 1, 1),
#                c(1, 1, 0, 1, 1, 1),
#                c(0, 0, 1, 1, 0, 0),
#                c(1, 1, 1, 1, 0, 0),
#                c(0, 1, 0, 1, 1, 0),
#                c(0, 0, 1, 0, 0, 0),
#                c(0, 0, 1, 0, 1, 0),
#                c(0, 0, 0, 0, 1, 0),
#                c(0, 1, 0, 1, 1, 0),
#                c(0, 0, 0, 0, 0, 1))
# inMat



doCVPositiveOnly3 <- function(inMat, kfold = 10, numSplit = 5) {
  ##---INPUT
  # inMat: matrix
  # kfold: scalar, integer
  # numSplit: scalar, integer, number of splits
  #---OUTPUT
  # list, a list of multiple components
  
  
  # library(reshape2)
  # library(data.table)
  
  

  rownames(inMat) <- NULL
  colnames(inMat) <- NULL
  
  
  # width -> length, stack by column
  # i, j, v format
  triplet <- as.data.table(reshape2::melt(inMat))
  setnames(triplet, c("rowIndex", "colIndex", "value"))
  
  numTri <- nrow(triplet)
  
  # just obtain test set from ONEs, not include ZEROs
  tripletOnes <- triplet[value == 1, ]
  valUsr <- tripletOnes[, .N, by = colIndex][N > 2, ][, colIndex]
  tripletOnes <- tripletOnes[colIndex %in% valUsr, ]
  valObj <- tripletOnes[, .N, by = rowIndex][N > 2][, rowIndex]
  tripletOnes <- tripletOnes[rowIndex %in% valObj, ]
  
  
  numTriOnes <- nrow(tripletOnes)
  
  
  #####################   nested list   ############
  # save final list
  # nested list, should define two lists
  savedFolds <- vector(mode = "list", length = numSplit)
  names(savedFolds) <- paste0("split_", 1:numSplit)
  
  # save kfold list for each split
  cvFolds <- vector("list", length = kfold)
  names(cvFolds) <- paste0("fold_", 1:kfold)
  ##################################################
  
  
  source("getCvIndex.R")
  
  for (i in 1:numSplit) {
    
    
    isThisFolds <- TRUE
    while (isThisFolds) {
      #===================================================
      # here totNum should be numTriOnes, not numTri
      # 'folds' is a list
      folds <- getCvIndex(totNum = numTriOnes, nfold = kfold)
      #===================================================
      for (j in 1:kfold) {
        currIndex <- sort(folds[[j]])
        testData <- tripletOnes[currIndex]
        testIndex <- testData[, 1:2, with = FALSE]
        tmp <- inMat
        testSet<- as.matrix(testIndex)
        tmp[testSet] <- 0
        rs <- rowSums(tmp) # not good CV?
        cs <- colSums(tmp) # not good CV?

        if ((0 %in% rs) || (0 %in% cs)) {
          isThisFolds <- TRUE
          # jump out for-loop and perform while() function
          break
        } else {
          # quit while() function
          isThisFolds <- FALSE
        }
      }
    }
    
    
    for (j in 1:kfold) {
      
      currIndex <- sort(folds[[j]])
      
      # test set just from ONEs
      testData <- tripletOnes[currIndex]
      

      
      testIndex <- testData[, 1:2, with = FALSE]
      
      
      testIndexRow <- testIndex[, rowIndex]
      testIndexCol <- testIndex[, colIndex]
      
      # known information for drug-target matrix
      tmpTriplet <- triplet
      # not this one, since we just select test set
      # from ONEs
      # tmpTriplet[currIndex, "value"] <- 0 
      
      # add additional column in order to subset for test one
      # rowIndex and colIndex combination
      tmpTriplet[, rcCom := paste0(rowIndex, ".", colIndex)]
      # combine rowIndex and colIndex of test set in order to subset
      tsCom <- testIndex[, paste0(rowIndex, ".", colIndex)]
      # should be "value"
      tmpTriplet[rcCom %in% tsCom, "value"] <- 0
      # for testing, it should be all ZEROs for these test set entries
      # tmpTriplet[rcCom %in% tsCom, ]
      
      knownInteraction <- tmpTriplet[value > 0]
      # vector
      knownDrugIndex <- sort(unique(knownInteraction[, rowIndex]))
      # vector
      knownTargetIndex <- sort(unique(knownInteraction[, colIndex]))
      
      # fold matrix in the test set
      tmp <- inMat
      # numTestSet * 2 matrix
      testSet<- as.matrix(testIndex)
      tmp[testSet] <- 0
      
      # 1. it is a mtrix
      cvFolds[[j]]$testSet <- testSet
      # 2. it is a vector
      cvFolds[[j]]$testIndexRow <- testIndexRow
      # 3. it is a vector
      cvFolds[[j]]$testIndexCol <- testIndexCol
      # 4. it is a vector
      cvFolds[[j]]$knownDrugIndex <- knownDrugIndex
      # 5. it is a vector
      cvFolds[[j]]$knownTargetIndex <- knownTargetIndex
      # 6. Yfold matrix
      cvFolds[[j]]$foldMat <- tmp
    }
    savedFolds[[i]] <- cvFolds
  }
  
  cat("save 'savedFolds.RData' to disk! \n")
  flush.console()
  
  # save(savedFolds, file = "savedFolds.RData")
  
  return(savedFolds)
}

