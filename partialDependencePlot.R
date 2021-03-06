
partialDependencePlot <- function(model, cols, data_frame, N=20, values = NULL){
  
  require(plyr)
  
  target_col <- model@parameters$y
  
  ncol <- length(cols)
  if(ncol > 1 & !is.null(values) & class(values)!='list'){
      stop("If # of cols is bigger than 1 then values should be a list NULL.")
  }
  types  <- h2o.getTypes(data_frame)
  
  lvalues <- lapply(cols, function(col){
    type  <- types[[which( names(data_frame) == col)]]
  
    vals <- values[[col]]
    
    if(is.null(vals)){
      if(type == "enum" | type == "string"){
        #vals = as.data.frame(h2o.unique(data_frame[,col]))
        tab <- as.data.frame(h2o.table(data_frame[,col]))
        n <- min(N,nrow(tab))
        vals <- as.character(tab[order(tab$Count, decreasing = T),][c(1:n),1])
      }else if(type == "int" | type == "real"){
        minVal <- min(data_frame[,col], na.rm=TRUE)
        maxVal <- max(data_frame[,col], na.rm=TRUE)
        
        quant  <- h2o.quantile(data_frame[,col], probs = c(0.02, 0.98))
        minVal.q <- min(quant)
        maxVal.q <- max(quant)
        
        len <- (maxVal.q - minVal.q)
        diff.min = abs(minVal - minVal.q)
        diff.max = abs(maxVal - maxVal.q)
        if( diff.min / len > 0.05){
          cat("Min value is much smaller than 2% quantile, hence, we use only values from 2% quantile.\n")
          cat("Min: ", minVal, "\t 2% quantile: ", minVal.q, "\n")
          minVal = minVal.q
        }
        if( diff.max / len > 0.05){
          cat("Max value is much bigger than 98% quantile, hence, we use only values from 98% quantile.\n")
          cat("Max: ", maxVal, "\t 98% quantile: ", maxVal.q, "\n")
          maxVal = maxVal.q
        }
        
        vals <- seq(minVal,maxVal,(maxVal-minVal)/(N-1))
        if(type == "int"){
          vals <- round(vals)
        }
      }else{  
        stop(" unknown type for " + prdictor_col)
      }
    }
    
    vals
  })
  
  origpreds <- h2o.predict(model, data_frame)
  
  dim_ <- sapply(lvalues, length)
  len <- prod(dim_)
  res <- array(rep(0,len))
  idx <- rep(1,ncol)
  dimc_ <- c(1,cumprod(dim_)[1:(ncol-1)])
  for(i in c(1:len)){
    rezid=i
    for(j in c(ncol:1)){
      idx[j]=floor((rezid-1)/dimc_[j])+1
      rezid = (rezid-1) %% dimc_[j] +1
    }
    tempframe <- data_frame
    for(ii in c(1:ncol)){
      type  <- types[[which( names(data_frame) == cols[ii])]]
      if(type == "enum"){
        tempframe[,cols[ii]] <- as.h2o(factor(rep(lvalues[[ii]][idx[ii]], nrow(data_frame))))
      }else{
        tempframe[,cols[ii]] <- lvalues[[ii]][idx[ii]]
      }
    }
    newpreds <- h2o.predict(model, tempframe)
    del <- mean(newpreds[,3]-origpreds[,3])

    res[i] <- del 
  }
  
  res <- array(res, dim = dim_, dimnames = lvalues)
 # p <- plot(values, 
 #           deltas,
 #           type='l', 
 #           main=paste0("Partial dependence plot for ", target_col, " as a function of ", predictor_col), 
 #           xlab=predictor_col, 
 #           ylab=paste0("delta.",target_col))
 # 
 # return(p)
  return(res)
}
