# I demonstrate how to use bootstrapping to do hypothesis testing 
# using a dataset `sleep` in tidyverse. It is to test wheather there is 
# a significant increase in the number of extra hours of sleep 
# compared to the control group.

library(tidyverse)
theme_set(theme_light())

sleep <- as_tibble(sleep)
print(sleep, n = 5)

# `t.test` is only valid when data are normally distributed. In reality, this is often not true.
test_sleep <- function(df) {
  df <- as_tibble(df)
  t.test(extra ~ group, data = df, alternative = "less")
}
theta_hat <- test_sleep(sleep)

# First sample under the null.
boot_null_factory <- function(df) {
  df <- as_tibble(df)
  groups <- df %>% pull(group)
  function(seed = 0) {
    set.seed(seed)
    sample_frac(df, replace = TRUE) %>% 
      mutate(group = groups)
  }
}

boot_null <- boot_null_factory(sleep)

# Create a tibble `boot_null_results` with values of the regression coefficients 
# averaged over an increasing number of bootstrap replicates.
boot_theta <- function(nboot, boot_fun, theta) {
  tibble(
    b = 1:nboot,
    df_b = map(b, ~ boot_fun(.x)),
    theta_b = map(df_b, theta)
  )
}

boot_null_results <- tibble(
  nboot = c(100, 200, 500, 1000),
  theta_b = map(nboot, boot_theta, boot_fun = boot_null, theta = test_sleep)
) %>%
  unnest(theta_b) %>%
  dplyr::select(-df_b) %>%
  mutate(theta_b = map_dbl(theta_b, "statistic"))

# Q-Q plot of `theta_b`
library(ggplot2)

ggplot(boot_null_results,
       aes(sample = theta_b)) +
  stat_qq_line(distribution = qnorm,
               color = "red",
               size = 1) +
  geom_qq(distribution = qnorm) +
  facet_wrap(~ nboot, labeller = 
               as_labeller(function(x) paste(x, "replicates"))) +
  labs(x = "Theoretical quantiles",
       y = "Sample quantiles")

# Extract the p values
boot_null_pval <- boot_null_results %>%
  group_by(nboot) %>%
  summarize(pval = mean(theta_b <= theta_hat$statistic))

print(boot_null_pval, n = 5)


