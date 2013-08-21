// Random.h
// random number generation using Mersenne Twister
// API follows torch.Random

#ifndef RANDOM_H
#define RANDOM_H

#include <inttypes.h>
#include <math.h>

// return sample from Bernouilli(p)
// return 1 with probability p and 0 with probability 1 - p for 0 < p < 1
extern unsigned Random_bernoulli(double p);

// return sample from Cauchy(mean, sigma)
// p(x) = sigma/(pi*sigma^2 + (x - median)^2)
extern double Random_cauchy(double median, double sigma);

// return sample from Exponential(lambda)
// p(x) = lambda * exp(-lambda * x)
extern double Random_exponential(double lambda);

// return sample from Geometric(p)
// p(i) = (1 - p) * p ^(i - 1) with 0 < p < 1
// where i is drawn from Uniform distribution {1, 2, ...}
extern unsigned Random_geometric(double p);

// return initial seed that was used to initialize random generator
extern unsigned long Random_initialSeed();

// return sample from LogNormal(mean, stdv)
// If X is normal, then Y=log(X) is logNormal
extern double Random_logNormal(double mean, double stdv);

// set and return random number seed using given number
extern unsigned long Random_manualSeed(unsigned long number);

// return sample from Normal(mean, stdv)
extern double Random_normal(double mean, double stdv);

// return random integer
extern unsigned long Random_random();

// set and return random number seed using system clock
// granulatiry is seconds
extern unsigned long Random_seed();

// return sample Uniform[low, high]
extern double Random_uniform(double low, double high);

#endif



















