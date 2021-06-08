#--------------1.Crear Portafolio de Inversión y Obtener datos-------------------------------
#Portafolio de : Li Lu - Himalaya Capital Management
library(tidyquant) 
library(timetk)
library(dplyr)
library(tidyverse)
library(ggplot2)
tickers <- c('MU', 'BAC', 'FB','GOOG', 'AAPL', 'PDD')
weight <- c(0.4752+1e-04, 0.2063+1e-04, 0.1445+1e-04, 0.0829+1e-04, 
            0.055+1e-04, 0.0355+1e-04)
portafolio_inv <- function(fecha_inicio = "2011-01-03", fecha_final){
  tickers_prices <- tq_get(tickers, get = "stock.prices",from = fecha_inicio,
                           to = fecha_final)
  groupbysymbol <- group_by(tickers_prices, symbol)
  retornos <- tq_transmute(data = groupbysymbol, mutate_fun = periodReturn,
                           select = adjusted, period = "daily", col_rename = "Ret")
  #portafolio <- tq_portfolio(data = retornos, assets_col = symbol, returns_col = Ret,
                             #weights = weight)
  wts_tbl <- tibble(symbol = tickers, wts = weight)
  ret_data <- left_join(retornos ,wts_tbl, by = 'symbol')
  ret_data <- ret_data %>% mutate(wt_return = wts * Ret)
  
  port_ret <- ret_data %>%
    group_by(date) %>%
    summarise(port_ret = sum(wt_return))
  port_cumulative_ret <- port_ret %>%
    mutate(cr = cumprod(1 + port_ret))
  grafica <- port_cumulative_ret %>%
    ggplot(aes(x = date, y = cr)) +
    geom_line() +
    labs(x = 'Date',y = 'Cumulative Returns',
         title = 'Portfolio Cumulative Returns') +
    theme_classic() +
    scale_y_continuous(breaks = seq(1,2,0.1)) +
    scale_x_date(date_breaks = 'year',
                 date_labels = '%Y')
  average_annual_port_ret <- tq_performance(port_cumulative_ret,Ra = port_ret,
                                            performance_fun = Return.annualized)
  promedio_anual_retorno <- paste("The average annual portfolio returns is ", 
                                  round((average_annual_port_ret[[1]] * 100),2),"%", sep = "")
  
  vola_d <- sd(port_cumulative_ret$port_ret)
  vola_d1 <- paste("The daily portfolio volatility is ",round((vola_d[[1]]),4))
  vola_a <- vola_d *sqrt(252)
  Sharp_Radio_Manual <- average_annual_port_ret$AnnualizedReturn / vola_a
  Sharp_Radio_R <- port_cumulative_ret %>% tq_performance(Ra = port_ret, 
                                                          performance_fun = SharpeRatio.annualized) %>% .[[1]]
  Sharp_Radio_R <- paste("The annual portfolio sharpe ratio calculated using the tq_performance function is"
                         ,round((Sharp_Radio_R[[1]]),4))
  Sharp_Radio_Manual <- paste("The annual portfolio sharpe ratio calculated without the tq_performance function is"
                              ,round((Sharp_Radio_Manual[[1]]),4))
  
  return(list(grafica, promedio_anual_retorno, vola_d1, Sharp_Radio_Manual, 
              Sharp_Radio_R))
}

portaf_invers <- portafolio_inv(fecha_final = "2019-12-31")

#-----------------------Buscar el portafolio Optimo---------------------------#
tickers_prices <- tq_get(tickers, get = "stock.prices")
ret_log <- tickers_prices %>% group_by(symbol) %>%
  tq_transmute(select     = adjusted,
               mutate_fun = periodReturn, 
               period     = "daily", 
               type       = "log",
               col_rename = "ret_log")
new_tib <-spread(ret_log, symbol, ret_log)
sin_na <- replace_na(new_tib,list(FB = 0.0, PDD = 0.0))
vec_prom_retl <- sin_na
vec_prom_retl$date <- NULL
vec_prom_retl
for_cov <- vec_prom_retl
promedio_cols<- colMeans(vec_prom_retl)
weight_new <- matrix(ncol = length(weight))
r_period <- matrix(nrow = 5000)
port_risk <- matrix(nrow = 5000)
shar_ratio <- matrix(nrow = 5000)

for (i in c(1:5000)) {
  random <- runif(length(weight))
  wei_norm <- random/sum(random)
  weight_new <- rbind(wei_norm,weight_new)
  retorno_total_random <- wei_norm * promedio_cols
  r_period[i] <- sum(retorno_total_random)
  r_annual <- (1+r_period)**(251)
  cov_mat <- cov(for_cov)
  port_risk[i] <- sqrt(t(array(wei_norm)) %*% (cov_mat %*% array(wei_norm)))
  shar_ratio[i] <- r_period[i] / port_risk[i]
}
weight_new <- weight_new[1:5000,1:6]
new_matrix<- cbind(weight_new,r_period, port_risk,shar_ratio )
colnames(new_matrix) <- c(tickers,"Return", "Risk", "SharpeRatio")
port_nuevo <- as_tibble(new_matrix)
Riesgo_min <- subset(port_nuevo, Risk == min(port_nuevo$Risk))
Riesgo_max <- subset(port_nuevo, Risk == max(port_nuevo$Risk))
plot_max <- c()
plot_min <- c()
for (j in c(1:length(tickers))) {
  plot_max[j] <- as.numeric(Riesgo_max[j])
  plot_min[j] <- as.numeric(Riesgo_min[j])   
}
barplot(plot_max, names.arg = tickers , xlab = "Assets", ylab= "Weights")
barplot(plot_min, names.arg = tickers , xlab = "Assets", ylab= "Weights")
portaf_invers

