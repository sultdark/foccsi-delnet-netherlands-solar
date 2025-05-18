# Load required libraries
library(magrittr)
library(dplyr)
library(readr)
library(ggplot2)
library(lubridate)

# Set path to merged file
merged <- read_csv("C:/Users/Mitarbeiter/Documents/FOCCSI/data/netherlands_solar_2024/merged.csv")

# Step 1: Prepare forecast and actual data
actual <- merged %>% select(datetime, value = actual)
forecast_d1 <- merged %>% select(datetime, value = forecast_d1)
forecast_d  <- merged %>% select(datetime, value = forecast_d)

# Step 2: Merge forecasts into one dataset
combined <- actual %>%
  rename(actual = value) %>%
  left_join(forecast_d1, by = "datetime") %>%
  rename(forecast_d1 = value) %>%
  left_join(forecast_d, by = "datetime") %>%
  rename(forecast_d = value)

# Step 3: Calculate forecast errors
combined <- combined %>%
  mutate(
    error_d1 = abs(forecast_d1 - actual),
    error_d  = abs(forecast_d  - actual)
  )

# Step 4: Plot actual vs forecasts
ggplot(combined, aes(x = datetime)) +
  geom_line(aes(y = actual), color = "black", linewidth = 1, alpha = 0.6) +
  geom_line(aes(y = forecast_d1), color = "blue", linetype = "dashed") +
  geom_line(aes(y = forecast_d), color = "red", linetype = "dotted") +
  labs(title = "Actual vs Forecasts", y = "Generation", x = "Time") +
  theme_minimal()

# Step 5: FOCCSI Optimization
f_d  <- combined$forecast_d
f_d1 <- combined$forecast_d1
act  <- combined$actual

results <- data.frame(weight = seq(0, 1, by = 0.01)) %>%
  rowwise() %>%
  mutate(
    mae = mean(abs((weight * f_d + (1 - weight) * f_d1) - act))
  )

# Step 6: Find optimal weight
optimal_weight <- round(results$weight[which.min(results$mae)], 2)




cat("\n✅ Optimal FOCCSI weight for intraday forecast:", optimal_weight, "\n")
cat("➡️  This means", round(optimal_weight * 100), "% intraday +", round((1 - optimal_weight) * 100), "% day-ahead\n")


# Step 7: Generate FOCCSI forecast
combined <- combined %>%
  mutate(
    foccsi = optimal_weight * forecast_d + (1 - optimal_weight) * forecast_d1
  )


# Step 8: Plot all together
ggplot(combined, aes(x = datetime)) +
  geom_line(aes(y = actual), color = "black", alpha = 0.6) +
  geom_line(aes(y = forecast_d1), color = "blue", linetype = "dashed") +
  geom_line(aes(y = forecast_d), color = "red", linetype = "dotted") +
  geom_line(aes(y = foccsi), color = "green", linetype = "dotdash") +
  labs(title = "FOCCSI: Optimized Forecast vs Actual",
       y = "Generation", x = "Time") +
  theme_minimal()

foccsi_mae <- mean(abs(combined$foccsi - combined$actual))
foccsi_rmse <- sqrt(mean((combined$foccsi - combined$actual)^2))

cat("📊 FOCCSI MAE:", round(foccsi_mae, 2), "\n")
cat("📊 FOCCSI RMSE:", round(foccsi_rmse, 2), "\n")

write_csv(combined, "C:/Users/Mitarbeiter/Documents/FOCCSI/data/netherlands_solar_2024/foccsi_results.csv")

# Step 9: Calculate MAE and RMSE for all methods
error_summary <- tibble(
  Method = c("Day-ahead", "Intraday", "FOCCSI"),
  MAE = c(
    mean(abs(combined$forecast_d1 - combined$actual)),
    mean(abs(combined$forecast_d  - combined$actual)),
    mean(abs(combined$foccsi      - combined$actual))
  ),
  RMSE = c(
    sqrt(mean((combined$forecast_d1 - combined$actual)^2)),
    sqrt(mean((combined$forecast_d  - combined$actual)^2)),
    sqrt(mean((combined$foccsi      - combined$actual)^2))
  )
)

print(error_summary)

# Step 10: Create bar plot for MAE and RMSE
library(tidyr)

# Reshape for plotting
error_long <- error_summary %>%
  pivot_longer(cols = c("MAE", "RMSE"), names_to = "Metric", values_to = "Value")

# Plot
ggplot(error_long, aes(x = Method, y = Value, fill = Metric)) +
  geom_bar(stat = "identity", position = "dodge") +
  labs(title = "Forecast Error Comparison: MAE vs RMSE",
       y = "Error Value", x = "Forecast Method") +
  theme_minimal() +
  scale_fill_manual(values = c("steelblue", "darkorange"))




