library(glmnet)
library(dplyr)
library(readr)
library(lubridate)

# Load data
data <- read_csv("C:/Users/Mitarbeiter/Documents/FOCCSI/data/netherlands_solar_2024/merged.csv")

# Ensure datetime sorted
data <- data %>% arrange(datetime)

# Extract forecast matrix and actuals
forecast_matrix <- data %>%
  select(forecast_d1, forecast_d) %>%
  as.matrix()

actual_vector <- data$actual
datetime_vector <- data$datetime

# Parameters


points_per_day <- 96           # 15-minute resolution
window_days <- 5             # training window in days
window_size <- window_days * points_per_day

if (window_size + 1 >= length(actual_vector)) {
  stop("❗ Not enough data for the chosen rolling window. Reduce 'window_days'.")
}

# Placeholder for results
meta_forecast <- rep(NA, length(actual_vector))
lambda_values <- rep(NA, length(actual_vector))

# Rolling forecast
for (i in seq(window_size + 1, length(actual_vector), by = points_per_day)) {
  train_index <- (i - window_size):(i - 1)
  predict_index <- i:(i + points_per_day - 1)
  predict_index <- predict_index[predict_index <= length(actual_vector)]
  
  x_train <- forecast_matrix[train_index, ]
  y_train <- actual_vector[train_index]
  
  # Cross-validated elastic net (alpha = 0.5)
  cv_fit <- cv.glmnet(x_train, y_train, alpha = 0.5)
  best_lambda <- cv_fit$lambda.min
  
  # Fit final model
  final_model <- glmnet(x_train, y_train, alpha = 0.5, lambda = best_lambda)
  x_predict <- forecast_matrix[predict_index, ]
  prediction <- predict(final_model, newx = x_predict)
  
  # Save results
  meta_forecast[predict_index] <- as.numeric(prediction)
  lambda_values[predict_index] <- best_lambda
}

# Create final results dataframe
results <- data.frame(
  datetime = datetime_vector,
  actual = actual_vector,
  forecast_d1 = forecast_matrix[,1],
  forecast_d = forecast_matrix[,2],
  foccsi_delnet = meta_forecast,
  lambda = lambda_values
)

# Add error columns
results <- results %>%
  mutate(
    error = abs(foccsi_delnet - actual),
    squared_error = (foccsi_delnet - actual)^2
  )

# Final metrics
mae_delnet <- mean(results$error, na.rm = TRUE)
rmse_delnet <- sqrt(mean(results$squared_error, na.rm = TRUE))

cat("📊 DELNET MAE:", round(mae_delnet, 2), "\n")
cat("📊 DELNET RMSE:", round(rmse_delnet, 2), "\n")

# Save output
write_csv(results, "C:/Users/Mitarbeiter/Documents/FOCCSI/data/netherlands_solar_2024/delnet_results.csv")


# Load FOCCSI and DELNET results
foccsi <- read_csv("C:/Users/Mitarbeiter/Documents/FOCCSI/data/netherlands_solar_2024/foccsi_results.csv")
delnet <- read_csv("C:/Users/Mitarbeiter/Documents/FOCCSI/data/netherlands_solar_2024/delnet_results.csv")

# Merge by datetime
comparison <- foccsi %>%
  select(datetime, actual, forecast_d1, forecast_d, foccsi) %>%
  left_join(delnet %>% select(datetime, foccsi_delnet), by = "datetime")

# Calculate MAE for comparison
mae_summary <- tibble(
  Method = c("Day-ahead", "Intraday", "FOCCSI", "DELNET"),
  MAE = c(
    mean(abs(comparison$forecast_d1 - comparison$actual), na.rm = TRUE),
    mean(abs(comparison$forecast_d  - comparison$actual), na.rm = TRUE),
    mean(abs(comparison$foccsi      - comparison$actual), na.rm = TRUE),
    mean(abs(comparison$foccsi_delnet - comparison$actual), na.rm = TRUE)
  )
)

print(mae_summary)

library(ggplot2)

ggplot(mae_summary, aes(x = Method, y = MAE, fill = Method)) +
  geom_bar(stat = "identity", width = 0.6) +
  labs(title = "Mean Absolute Error (MAE) by Forecast Method",
       y = "MAE (MW)", x = "Method") +
  theme_minimal() +
  theme(legend.position = "none")

library(dplyr)
library(lubridate)
library(tidyr)
library(ggplot2)

# Load data
data <- read_csv("C:/Users/Mitarbeiter/Documents/FOCCSI/data/netherlands_solar_2024/foccsi_results.csv")

# Calculate daily MSE
daily_errors <- data %>%
  mutate(date = as.Date(datetime)) %>%
  group_by(date) %>%
  summarise(
    Forecast_d1 = mean((forecast_d1 - actual)^2, na.rm = TRUE),
    Forecast_d  = mean((forecast_d  - actual)^2, na.rm = TRUE),
    FOCCSI      = mean((foccsi      - actual)^2, na.rm = TRUE)
  ) %>%
  pivot_longer(-date, names_to = "Method", values_to = "MSE")

# Plot
ggplot(daily_errors, aes(x = date, y = MSE, color = Method)) +
  geom_line(size = 1) +
  labs(title = "Forecasting Error per Method (Daily)",
       x = "Date", y = "Mean Squared Error (MW^2)") +
  theme_minimal()

# Add date column to both results
foccsi <- read_csv("C:/Users/Mitarbeiter/Documents/FOCCSI/data/netherlands_solar_2024/foccsi_results.csv") %>%
  mutate(date = as.Date(datetime))

delnet <- read_csv("C:/Users/Mitarbeiter/Documents/FOCCSI/data/netherlands_solar_2024/delnet_results.csv") %>%
  mutate(date = as.Date(datetime))

# Compute daily MSEs
combined_mse <- foccsi %>%
  left_join(delnet %>% select(datetime, foccsi_delnet), by = "datetime") %>%
  mutate(date = as.Date(datetime)) %>%
  group_by(date) %>%
  summarise(
    Average     = mean(((forecast_d1 + forecast_d)/2 - actual)^2, na.rm = TRUE),
    FOCCSI      = mean((foccsi - actual)^2, na.rm = TRUE),
    DELNET      = mean((foccsi_delnet - actual)^2, na.rm = TRUE),
    Providers   = 2  # constant for your case
  ) %>%
  pivot_longer(cols = c("Average", "FOCCSI", "DELNET"), names_to = "Method", values_to = "MSE")

# Plot
ggplot() +
  geom_col(data = distinct(combined_mse, date, Providers),
           aes(x = date, y = Providers * 1000), fill = "orange", alpha = 0.3) +
  geom_line(data = combined_mse, aes(x = date, y = MSE, color = Method), size = 1) +
  labs(title = "Forecasting Error: Combined Methods vs Number of Providers",
       x = "Date", y = "MSE (MW^2)") +
  theme_minimal()

