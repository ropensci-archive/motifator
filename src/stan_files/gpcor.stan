data {
  
  int X; //Number of cells in x dimension
  int N; //Total number of cells
  int NW; //Number of weighted spatial pairs
  real mean_p; //Avg proportion in group 1 in each cell
  real mean_p_sd; //SD of outcome across areas
  real target_i; //Target value of Moran's I
  real target_i_sd; //Target SD of Moran's I
  matrix[N,N] D; //Pairwise distances between cell
  int A[NW,2]; //adjacency weights
  real moran_i_ratio;
  
}

parameters {
  
  vector<lower=0, upper=1>[N] y;
  real<lower=0> sigma;
  real<lower=0> rho;
}

transformed parameters {
  matrix[N,N] K;
  vector[N] mu = rep_vector(0,N);
  real moran_i;
  real avg_y = mean(y);
  real sd_y = sd(y);
  real cv_y = avg_y/sd_y;
  {
    real moran_i_num = 0;
    real moran_i_denom = 0;
    for (i in 1:NW) {
     moran_i_num = moran_i_num + (y[A[i,1]]-avg_y)*(y[A[i,2]]-avg_y);
    }
    
    for (i in 1:N) {
     moran_i_denom = moran_i_denom + square(y[i]-avg_y);
    }
    moran_i = moran_i_ratio*(moran_i_num/moran_i_denom);
  }
  
  for (i in 1:(N-1)) {
    K[i,i] = 1 + sigma;
    for (j in (i+1):N) {
      K[i,j] = exp(-rho * square(D[i,j]));
      K[j,i] = K[i,j];
    }
  }
  K[N, N] = 1 + sigma;
}



model {
  
  sigma ~ normal(0, 4);
  rho ~ normal(0, 5);
  y ~ multi_normal(mu, K);
  avg_y ~ normal(mean_p, mean_p_sd);
  moran_i ~ normal(target_i, target_i_sd);
}

