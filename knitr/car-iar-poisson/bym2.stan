data {
  int<lower=0> N;
  int<lower=0> N_edges;
  int<lower=1, upper=N> node1[N_edges];  // node1[i] adjacent to node2[i]
  int<lower=1, upper=N> node2[N_edges];  // and node1[i] < node2[i]

  int<lower=0> y[N];              // count outcomes
  vector<lower=0>[N] E;           // exposure
  //  int<lower=1> K;                 // num covariates
  //  matrix[N, K] x;                 // design matrix

  real<lower=0> scaling_factor; // scales the variance of the spatial effects
}
transformed data {
  vector[N] log_E = log(E);
}
parameters {
  real beta0;            // intercept
  //  vector[K] betas;       // covariates

  real<lower=0> sigma;        // overall standard deviation
  real<lower=0, upper=1> rho; // proportion unstructured vs. spatially structured variance

  vector[N] theta;       // heterogeneous effects
  vector[N - 1] phi_raw; // raw spatial effects
}
transformed parameters {
  vector[N] phi;
  vector[N] convolved_re;

  phi[1:(N - 1)] = phi_raw;
  phi[N] = -sum(phi_raw);

  // variance of each component should be approximately equal to 1
  convolved_re =  sqrt(1 - rho) * theta + sqrt(rho / scaling_factor) * phi;
}
model {
  y ~ poisson_log(log_E + beta0 + convolved_re * sigma); // no co-variates
  //  y ~ poisson_log(log_E + beta0 + x * betas + convolved_re * sigma);  // co-variates

  // This is the prior for phi! (up to proportionality)
  target += -0.5 * dot_self(phi[node1] - phi[node2]);

  beta0 ~ normal(0.0, 2.5);
  //  betas ~ normal(0.0, 2.5);
  theta ~ normal(0.0, 1.0);
  sigma ~ normal(0,5);
  rho ~ beta(0.5, 0.5);
}
generated quantities {
  real logit_rho = log(rho / (1.0 - rho));
  // compute posterior predictive probability
  vector[N] eta = log_E + beta0 + convolved_re * sigma; // no co-variates
  //  vector[N] eta = log_E + beta0 + x * betas + convolved_re * sigma; // co-variates
  vector[N] mu = exp(eta);
  int y_rep[N];
  if (max(eta) > 20) {
    print("max eta too big: ", max(eta));
    for (n in 1:N) {
      y_rep[n] = -1;
    }
  } else {
      for (n in 1:N) {
        y_rep[n] = poisson_log_rng(eta[n]);
      }
  }
}
