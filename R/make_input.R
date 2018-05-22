#' Make data frame with moore neighbors
#'
#' @param grid_width Number of cells in X direction (assuming X = Y for square grid)
#' @return An object of class `list` containing adjacency matrix information, etc
#'
makeMooreNeighbors <- function(coords) {
  
  moore_neighbors <- data.frame()
  ## First do left
  left_neighbors <- data.frame(id = coords$id, 
                               x = coords$x-1,
                               y = coords$y)
  
  moore_neighbors <- rbind(moore_neighbors, left_neighbors)
  
  ## Then do right
  right_neighbors <- data.frame(id = coords$id, 
                                x = coords$x+1,
                                y = coords$y) 
  
  moore_neighbors <- rbind(moore_neighbors, right_neighbors)
  
  ## Above
  above_neighbors <- data.frame(id = coords$id, 
                                x = coords$x,
                                y = coords$y+1) 
  
  moore_neighbors <- rbind(moore_neighbors, above_neighbors)
  
  ## Below
  below_neighbors <- data.frame(id = coords$id, 
                                x = coords$x,
                                y = coords$y-1) 
  
  moore_neighbors <- rbind(moore_neighbors, below_neighbors)
  
  ## Above-left
  above_left_neighbors <- data.frame(id = coords$id, 
                                     x = coords$x-1,
                                     y = coords$y+1) 
  
  moore_neighbors <- rbind(moore_neighbors, above_left_neighbors)
  
  
  ## Above-right
  above_right_neighbors <- data.frame(id = coords$id, 
                                      x = coords$x+1,
                                      y = coords$y+1) 
  
  moore_neighbors <- rbind(moore_neighbors, above_right_neighbors)
  
  ## Below-left
  below_left_neighbors <- data.frame(id = coords$id, 
                                     x = coords$x-1,
                                     y = coords$y-1) 
  
  moore_neighbors <- rbind(moore_neighbors, below_left_neighbors)
  
  ## Below-right
  below_right_neighbors <- data.frame(id = coords$id, 
                                      x = coords$x+1,
                                      y = coords$y-1) 
  
  moore_neighbors <- rbind(moore_neighbors, below_right_neighbors)
  
  moore_neighbors <- moore_neighbors %>%
    dplyr::filter(x >= min(coords$x), 
           y >= min(coords$y), 
           y <= max(coords$y), 
           x <= max(coords$x)) %>%
    dplyr::arrange(id)
  
  
  return(moore_neighbors)
  
}

#' Make basic input data that can be used across models
#'
#' @param grid_width Number of cells in X direction (assuming X = Y for square grid)
#' @return An object of class `list` containing adjacency matrix information, etc
#' @importFrom magrittr %>%
#'
genericInputData <- function(grid_width) {
  ## Number of cells in X dimension
  X <- grid_width
  
  ## Total number of cells
  N <- X * X
  
  ## Get all X,Y relationships
  coords <- expand.grid(1:X, 1:X)
  colnames(coords) <- c("x", "y")
  coords$id <- 1:nrow(coords)
  
  ## Get all pairwise distances
  D <- coords %>% dist %>% as.matrix
  
  ## Get adjacency relationships
  A <- coords %>% makeMooreNeighbors
  
  ##Turn into adjacency list
  adj_list <- A %>%
    dplyr::rename(from_id = id) %>%
    dplyr::inner_join(coords) %>%
    dplyr::select(from_id,
           to_id = id)
  
  NW <- nrow(adj_list)
  
  data_in <- list(
    coords = coords,
    X = X,
    N = N,
    D = D,
    A = adj_list,
    NW = NW,
    moran_i_ratio = N / NW
  )
  
  return(data_in)
  
}

#' Unpack fitted model into a more plotting-friendly format
#'
#' @param data_in Input data for model
#' @param m Fitted model of class `stanmodel` 
#' @return An object of class `data.frame` with sampled values
#'
unpackProportionModel <- function(data_in, m) {
  
  ## Extract
  z <- rstan::extract(m)
  
  ## Get number of iterations
  niter <- length(z$moran_i)
  df_list <-list() 
  for (i in 1:niter) {
    tmp_df <- data.frame(x = data_in$coords$x,
                         y = data_in$coords$y,
                         value = z$y[i,])
    tmp_df$iter <- i
    tmp_df$i <- z$moran_i[i]
    tmp_df$sd <- z$sd_y[i]
    tmp_df$y_bar <- z$avg_y[i]
    
    df_list[[i]] <- tmp_df
  }
  
  out_df <- do.call(rbind, df_list)
  return(out_df)
  
}

#' Sample map with fixed proportions in each cell
#'
#' @export
#' @param grid_width X dimension of grid
#' @param i_target Value of Moran's I we're shooting for
#' @param i_sd Value of SD of Moran's I we're trying to get to
#' @param mean_target Mean proportion
#' @param mean_sd SD of mean across samples
#' @param nchain Number of chains
#' @param niter Number of iterations
#' @return An object of class `stanfit` returned by `rstan::sampling`
#'
sampleProportion <- function(grid_width, i_target = 0, i_sd = 0.1, mean_target = 0.9, mean_sd = 0.1, nchain = 1, niter = 1000) {
  
  ## Get basic input matrix data and add in model-specific parameters
  data_in <- genericInputData(grid_width)
  data_in$target_i <- i_target
  data_in$target_i_sd <- i_sd
  data_in$mean_p <- mean_target
  data_in$mean_p_sd <- mean_sd
  
  m <- rstan::sampling(stanmodels$gpcor, 
                       data = data_in,
                       iter = niter,
                       chains = nchain)
  
  out_samples <- unpackProportionModel(data_in, m)
  
  return(out_samples)

}
#' Sample map with fixed proportions in each cell
#'
#' @export
#' @param Item of class `data.frame` with sampled values
#' @param iter Which model iteration to use (defaults to random selection)
#' @import ggplot2
#' @importFrom magrittr %>%
plotMap <- function(sample_df, iter = FALSE) {
  
  ## If iter isn't specified, sample one
  if (iter == FALSE) {
    plot_iter <- sample(unique(sample_df$iter),1)
  } else {
    plot_iter <- iter
  }
  
  plot_df <- sample_df %>% 
    dplyr::filter(iter == plot_iter)
  
  g <- ggplot(plot_df, aes(x=x,y=y,fill = value)) + 
  geom_tile() + 
  scale_fill_gradient(low = "blue", high = "green") + 
  coord_equal()
  
  return(g)
}


