

cbp <- c("#999999", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7")




COL_ID        <-    0 + 1
COL_TRT       <-    1 + 1
COL_ACCRT     <-    2 + 1
COL_AGE       <-    3 + 1

COL_SEROT2    <-    4 + 1
COL_SEROT3    <-    5 + 1
COL_PROBT3    <-    6 + 1

COL_EVTT      <-    7 + 1

COL_FU1       <-    8 + 1
COL_FU2       <-    9 + 1

COL_CEN       <-    10 + 1
COL_OBST      <-    11 + 1



COL_THETA0    <-    0+1
COL_THETA1    <-    1+1
COL_DELTA     <-    2+1

dnames <- c("id", "trt", "accrt", "age", 
            "serot2", "serot3", "probt3", 
            "evtt", "fu1", "fu2", "cen", "obst", 
              "reason", "impute", "reftime")



# To test, type test_file('util.R')

state_reason <- function(x){
  if(x == 1) {
    message("(1: observed event before reftime & age <= age_max)")
    message("(1: obst = evtt)")
    }
  if(x == 2) {
    message("(2: event before reftime but age @ evtt > age_max - age_0)")
    message("(2: obst = age_max - age_0)")
    }
  if(x == 3) {
    message("(3: event after reftime & reftime - accru <= age_max - age_0)")
    message("(3: obst = ref_time - accrual)")
    }
  if(x == 4) {
    message("(4: event after reftime & reftime - accru > age_max - age_0)")
    message("(4: obst = age_max - age_0)")
    }
}

obs_summary <- function(d2, idx, look, cfg){

  message("subject                     ", d2$id[idx])
  message("interim time                ", cfg$interimmnths[look])
  message("interim + fu time           ", round(d2$reftime[idx], 1))
  message("time of event (accr + evtt) ", round(d2$accrt[idx], 1), " + ", 
    round(d2$evtt[idx], 1), " = ", round(d2$accrt[idx] + d2$evtt[idx], 1))
  message("age @ event (age_0 + evtt)  ", round(d2$age[idx], 1), " + ", 
    round(d2$evtt[idx], 1), " = ", round(d2$age[idx] + d2$evtt[idx], 1))
  message("observed tte                ", round(d2$obst[idx], 1))
  message("censored                    ", d2$cen[idx])
  message("reason                      ", d2$reason[idx])
  state_reason(d2$reason[idx])
  message("impute                      ", d2$impute[idx])

}


compute_sero_delta <- function(p_ctl, p_trt){
  
  delta <- (p_trt - p_ctl)/ (1 - p_ctl)
  delta
  
}

compute_exp_rate <- function(med){
  return(log(2)/med)
}


convert_to_df <- function(m){
  
  d2 <- as.data.frame(m)
  names(d2) <- dnames
  return(d2)
}

sim_cfg <- function(cfgfile = "cfg1.yaml", opt = NULL){
  
  tt <- tryCatch(configtmp <- read.config(file = cfgfile),
                 error=function(e) e, 
                 warning=function(w) w)
  ifelse(is(tt,"warning") | is(tt,"error"),"Configuration Warning/Error. 
         Please ensure configuration file has terminating empty line.",
         "Configuration File Loaded OK")
  
  flog.info("Using configuration: %s.", cfgfile)

  l <- list()
  
  # Precedence:
  # TRACE, DEBUG, INFO, WARN, ERROR, FATAL
  
  thres <- unlist(tt$logging[[3]][1])
  tl <- list("TRACE" = 9,
             "DEBUG" = 8,
             "INFO" = 6,
             "WARN" = 4,
             "FATAL" = 1)
  whichappender <- unlist(tt$logging[[1]][1])
  flog.info("  logging to: %s appender.", whichappender)
  logfile <- unlist(tt$logging[[2]][1])
  flog.info("  logfile   : %s", logfile)
  appender <- NULL
  if(whichappender == "file"){
    flog.appender(appender.file(file.path(getwd(), "logs", logfile)), name='ROOT')
    
  }
  if(whichappender == "console"){
    flog.appender(appender.console(), name='ROOT')
  }
  flog.threshold(futile.logger::DEBUG)



  l$flog_appender <- whichappender
  l$flog_logfile <- logfile
  
  l$dnames <- dnames
  
  # not used
  l$desc <- tt$desc
  l$outfile <- tt$outfile
  
  # for return fields
  l$field_names <- c("idxsim",
                   "look",
                   "n_obs",
                   "ss_immu",
                   "ss_clin",
                   "n_max",
                   "n_max_sero",
                   
                   "i_ppos_n", "i_ppos_max", "i_post_prop_ctl", "i_post_prop_trt",  # immunological
                   "i_delta_mean", "i_delta_lwr_95", "i_delta_upr_95",          # immunological
                   
                   "c_ppos_n","c_ppos_max","c_post_lambda_ctl","c_post_lambda_trt", # clinical
                   "c_lambda_mean", "c_lambda_lwr_95", "c_lambda_upr_95",       # clinical
                   
                   "stop_v_samp",
                   "stop_i_fut",
                   "stop_c_fut",
                   "stop_c_sup",
                   "inconclusive")
  
  

  
  l$simret <- list(idxsim = numeric(),
             look = numeric(),
             n_obs = numeric(),
             ss_immu = numeric(),
             n_max = numeric(),
             n_max_sero = numeric(),
             
             i_nobs = numeric(),
             i_nimpute1 = numeric(),
             i_nimpute2  = numeric(),
             i_n_sero_ctl = numeric(),
             i_n_sero_trt = numeric(),
             i_t0_mean = numeric(),
             i_t0_lwr = numeric(),
             i_t0_upr = numeric(),
             i_t1_mean = numeric(),
             i_t1_lwr = numeric(),
             i_t1_upr = numeric(),
             i_del_mean = numeric(),
             i_del_lwr = numeric(),
             i_del_upr = numeric(),
             i_pposn  = numeric(),
             i_pposmax = numeric(),
             
             stop_v_samp = numeric(),
             stop_i_fut = numeric(),
             stop_c_fut = numeric(),
             stop_c_sup = numeric(),
             inconclusive = numeric())
  
  
  # "stop_i_sup",
  
  l$immu_rtn_names <- c("ppos_n", "ppos_max", "mean_post_prop_ctl", "mean_post_prop_trt",
                        "delta", "delta_lwr_95", "delta_upr_95")
  l$clin_rtn_names <- c("ppos_n", "ppos_max", "mean_post_lambda_ctl", "mean_post_lambda_trt", 
                        "delta", "delta_lwr_95", "delta_upr_95")


  # Sim control variables
  l$idsim <- tt$idsim
  l$nsims <- tt$nsims 
  l$seed <- tt$seed
  
  # interims
  l$nstart <- tt$nstart
  l$nstop <- tt$nstop 
  l$interim_period <- tt$interim_period 
  l$people_per_interim_period <- tt$people_per_interim_period 
  l$nmaxsero <- tt$nmaxsero  
  l$nstartclin <- tt$nstartclin
  
  l$looks <- seq(from = l$nstart, to=l$nstop, by = 50)
  # ensure max is exactly 1000
  if(max(l$looks) < l$nstop){
    l$looks <- c(l$looks, l$nstop)
  }
  l$nlooks <- length(l$looks)
  
  # accrual - it takes months_per_person months to recruite one person
  l$months_per_person <- l$interim_period / l$people_per_interim_period
  
  l$months_to_nstart <- l$months_per_person * l$nstart
  
  l$interimmnths <- seq(from = l$months_to_nstart , 
                        to= ((length(l$looks)-1) * l$interim_period) + l$months_to_nstart, 
                        by = l$interim_period)
  # unnecessary
  if(length(l$interimmnths) < length(l$looks)){
    l$interimmnths <- c(l$interimmnths, max(l$interimmnths)+l$interim_period)
  }
  
  # the target size is the number of participants if accrual is going at 
  # the desired rate.
  # 70, 120, 170 etc
  l$looks_target <- seq(from = l$nstart, to=l$nstop, by = 50)
  tmpextra <- length(l$looks) - length(l$looks_target)
  l$looks_target <- c(l$looks_target, rep(l$nstop, tmpextra))
  
  stopifnot(length(l$looks_target) == length(l$looks))
  stopifnot(length(l$interimmnths) == length(l$looks))
  stopifnot(max(l$looks) == l$nstop)


  # data generation

  
  
  # not currently used
  l$trtallocprob <- tt$trtallocprob   
  l$remoteprob <- tt$remoteprob      
  
  # used to simulate age of participants - used in the tte modelling 
  l$age_months_lwr <- tt$age_months_lwr 
  l$age_months_upr <- tt$age_months_upr 
  l$age_months_mean <- tt$age_months_mean 
  l$age_months_sd <- tt$age_months_sd
  
  l$max_age_fu_months <- tt$max_age_fu_months
  
  # we delay the final analysis until the youngest kid is 36 months 
  l$final_analysis_month <- l$max_age_fu_months - l$age_months_lwr + max(l$interimmnths)

  l$sero_info_delay <- tt$sero_info_delay

  # seroconversion control variables
  # note - need to build utility functions to compute these
  l$baselineprobsero <- tt$baselineprobsero 
  l$trtprobsero <- tt$trtprobsero
  
  
  l$deltaserot3 <- compute_sero_delta(l$baselineprobsero, l$trtprobsero)
    

  # l$deltaremoteserot3 <- tt$deltaremoteserot3 


  # time to event control variables

  
  # time to event control variables
  # exponential
  # rates obtained from formula for med surv time (which are in months)
  # control log(2)/25 
  # treatment log(2)/30 - log(2)/25 
  # log(2)/25  = 0.027773
  # log(2)/30  = 0.023105
  
  # note - interp of survreg is fuckt 
  # see https://www.ms.uky.edu/~mai/Rsurv.pdf (top of page 4)
  # coefs aka. mu are related to rate via
  # mu = log(1/rate) 
  # i.e. rate = 1/exp(mu)
  
  # ignore the following - it relates to lognormal
  # for lognormal median is actually exp(mu) where mu represents
  # the mean parameter to a normal distribution, X for which
  # the lognormal dist is Y ~ exp(X) because the surv func
  # S(t) = 1 - CDF((ln(t) - μ) / σ) when equal to 0.5 gives
  # t_med = exp(μ).
  # So:
  # exp(3.4) ~= 30 months median survival for the control group
  # i.e. the time when surv prob equals 0.5 is about 30 months
  # exp(3.65) ~= 38 months
  #

  l$ctl_med_tte <- tt$ctl_med_tte
  l$trt_med_tte <- tt$trt_med_tte
  
  l$b0tte <- log(2)/l$ctl_med_tte 
  l$b1tte <- (log(2)/l$trt_med_tte) - (log(2)/l$ctl_med_tte)
  
  # Ideally would like to incorporate serot2 status
  l$btte <- c(l$b0tte, l$b1tte)
  
  l$ftte <- tt$ftte
  l$ttemodfile <- tt$ttemodfile
  
  # surveillance
  # fu 1 is between 14 and 21 days from accrual
  # fu 2 is between 28 and 55 days from accrual
  l$fu1_lwr <- 14/(365.25/12)
  l$fu1_upr <- 21/(365.25/12)
  l$fu2_lwr <- 28/(365.25/12)
  l$fu2_upr <- 55/(365.25/12)
  
  # 6 months plus or minus two week
  l$visit_lwr <- 5.5
  l$visit_upr <- 6.5
  
  l$surveillance_mnths <- 6
  
  
  
  
  
  # for final analysis test
  l$post_final_thresh <- tt$post_final_thresh
  
  
  
  
  
  
  
  # for significance testing of a win in the ppos section 
  l$post_tte_win_thresh_start <- tt$post_tte_win_thresh_start 
  l$post_tte_win_thresh_end <- tt$post_tte_win_thresh_end
  n1 <- length(l$looks[l$looks < l$nstartclin])
  n2 <- length(l$looks) - n1
  l$post_tte_win_thresh <- c(rep(l$post_tte_win_thresh_start, n1), 
                             seq(from = l$post_tte_win_thresh_start,
                             to = l$post_tte_win_thresh_end,
                             length.out = n2))
  stopifnot(length(l$post_tte_win_thresh) == length(l$looks))
    

  
  
  
  
  
  # for significance testing of a win in the ppos section 
  l$post_sero_win_thresh_start <- tt$post_sero_win_thresh_start 
  l$post_sero_win_thresh_end <- tt$post_sero_win_thresh_end
  n_sero_looks <- length(l$looks[l$looks <= l$nmaxsero])
  
  l$post_sero_win_thresh <- seq(from = l$post_sero_win_thresh_start,
                            to = l$post_sero_win_thresh_end,
                            length.out = n_sero_looks)
        
  
             
  
  
         
  
  # thresholds for interim decisions
  
  # futility tests - proportion of trials that must succeed else deemed futile
  l$pp_sero_fut_thresh <- tt$pp_sero_fut_thresh
  l$pp_tte_fut_thresh <- tt$pp_tte_fut_thresh
  
  
  
  
  
  
  # stop v sampling test
  l$pp_sero_sup_thresh <- tt$pp_sero_sup_thresh
  
  
  
  
  
  # superiority tte test - can ramp
  l$post_tte_sup_thresh_start  <- tt$post_tte_sup_thresh_start
  l$post_tte_sup_thresh_end  <- tt$post_tte_sup_thresh_end
  
  clin_looks <- l$looks[l$looks >= l$nstartclin]
  l$post_tte_sup_thresh <- seq(from = l$post_tte_sup_thresh_start,
                                   to = l$post_tte_sup_thresh_end,
                                   length.out = ceiling(length(clin_looks)))
  
  l$post_tte_sup_thresh <- c(rep(l$post_tte_sup_thresh[1],
                                     length(l$looks[l$looks < l$nstartclin])), 
                                 
                                 l$post_tte_sup_thresh,
                                 
                                 rep(l$post_tte_sup_thresh[ceiling(length(clin_looks))],
                                     length(l$looks) - 
                                       length(l$looks[l$looks < l$nstartclin]) - 
                                       ceiling(length(clin_looks)))
                                 )
  
  stopifnot(length(l$post_tte_sup_thresh) == length(l$looks))
  
  
  
  
  

  
  
  
  
  
  
  # bayesian model control parameters
  
  # number of posterior draws to make 
  # relevant to both posterior and post predictive sections
  l$post_draw <- tt$post_draw
  
  # no longer using mcmc
  # mcmc
  l$mcmcchains <- tt$mcmcchains
  l$mcmciter <- tt$mcmciter
  l$mcmcburnin <- tt$mcmcburnin
  l$mcmcthin <- tt$mcmcthin
  l$mcmcadapt <- tt$mcmcadapt
  
  l$mcmc_gchains <- tt$mcmc_gchains
  l$mcmc_giter <- tt$mcmc_giter
  l$mcmc_gburnin <- tt$mcmc_gburnin
  l$mcmc_gthin <- tt$mcmc_gthin
  l$mcmc_gadapt <- tt$mcmc_gadapt
  l$mcmc_giterkeep <- seq(from = l$mcmc_gburnin+1,
                          to = l$mcmc_giter,
                          by = l$mcmc_gthin)
  
  l$mcmc_nim_chains <- tt$mcmc_nim_chains
  l$mcmc_nim_iter <- tt$mcmc_nim_iter
  l$mcmc_nim_burnin <- tt$mcmc_nim_burnin
  l$mcmc_nim_thin <- tt$mcmc_nim_thin
  l$mcmciterfin <- c(l$mcmciter - l$mcmcburnin) / l$mcmcthin
  
  
  l$prior_gamma_a <- tt$prior_gamma_a
  l$prior_gamma_b <- tt$prior_gamma_b
  l$use_alt_censoring <- tt$use_alt_censoring
  
  
  if(opt$use){
    
    cat("*** Updating config.*** \n")
    flog.info("Updating configuration values based on command line arguments: %s", paste0(opt, collapse = " "))

    if(!is.null(opt$logfile)){
      l$flog_logfile <- opt$logfile

      flog.info("Updated logfile: %s", l$flog_logfile)
      
      if(whichappender == "file"){
        cat(paste0("New logfile ", file.path(getwd(), "logs", l$flog_logfile), "\n"))
        flog.appender(appender.file(file.path(getwd(), "logs", l$flog_logfile)), name='ROOT')
      }
    }
    
    flog.info("\n\n*** Updating config.*** \n")
    
    if(!is.null(opt$idsim)){
      l$idsim <- opt$idsim
      flog.info("Updated idsim: %s", l$idsim)
    }
    
    if(!is.null(opt$nsims)){
      l$nsims <- opt$nsims
      flog.info("Updated nsims: %s", l$nsims)
    }
    
    if(!is.null(opt$seed)){
      l$seed <- opt$seed
      flog.info("Updated seed: %s", l$seed)
    }

    if(!is.null(opt$accrual)){
      
      flog.info("*** Updating based on new accrual rates: %s", opt$accrual)
      
      l$people_per_interim_period <- opt$accrual
      flog.info("Updated people_per_interim_period: %s", l$people_per_interim_period)
      
      l$looks <- seq(from = l$nstart, to=l$nstop, by = l$people_per_interim_period)
      # ensure max is exactly 1000
      if(max(l$looks) < l$nstop){
        l$looks <- c(l$looks, l$nstop)
      }
      flog.info("Updated looks: %s", paste0(l$looks, collapse = ", "))
      l$nlooks <- length(l$looks)
      flog.info("Updated nlooks: %s", l$nlooks)
      
      # accrual - it takes months_per_person months to recruite one person
      l$months_per_person <- l$interim_period / l$people_per_interim_period
      flog.info("Updated months_per_person: %s", l$months_per_person)
      l$months_to_nstart <- l$months_per_person * l$nstart
      flog.info("Updated months_to_nstart: %s", l$months_to_nstart)
      
      l$interimmnths <- seq(from = l$months_to_nstart , 
                            to= ((length(l$looks)-1) * l$interim_period) + l$months_to_nstart, 
                            by = l$interim_period)
      
      if(length(l$interimmnths) < length(l$looks)){
        l$interimmnths <- c(l$interimmnths, max(l$interimmnths)+l$interim_period)
      }
      
      # we delay the final analysis until the youngest kid is 36 months 
      l$final_analysis_month <- l$max_age_fu_months - l$age_months_lwr + max(l$interimmnths)
      

      stopifnot(length(l$interimmnths) == length(l$looks))
      stopifnot(max(l$looks) == l$nstop)
      
      
      flog.info("Updated interimmnths: %s", paste0(l$interimmnths, collapse = ", "))
      
      clin_looks <- l$looks[l$looks >= l$nstartclin]
      l$post_tte_sup_thresh <- seq(from = l$post_tte_sup_thresh_start,
                                   to = l$post_tte_sup_thresh_end,
                                   length.out = ceiling(length(clin_looks)))
      
      l$post_tte_sup_thresh <- c(rep(l$post_tte_sup_thresh[1],
                                     length(l$looks[l$looks < l$nstartclin])), 
                                 
                                 l$post_tte_sup_thresh,
                                 
                                 rep(l$post_tte_sup_thresh[ceiling(length(clin_looks))],
                                     length(l$looks) - 
                                       length(l$looks[l$looks < l$nstartclin]) - 
                                       ceiling(length(clin_looks)))
      )
      
      stopifnot(length(l$post_tte_sup_thresh) == length(l$looks))

      flog.info("Updated post_tte_sup_thresh: %s", paste0(l$post_tte_sup_thresh, collapse = ", "))

      # for significance testing of a win in the ppos section 
      n1 <- length(l$looks[l$looks < l$nstartclin])
      n2 <- length(l$looks) - n1
      l$post_tte_win_thresh <- c(rep(l$post_tte_win_thresh_start, n1), 
                                 seq(from = l$post_tte_win_thresh_start,
                                     to = l$post_tte_win_thresh_end,
                                     length.out = n2))
      stopifnot(length(l$post_tte_win_thresh) == length(l$looks))
      
      flog.info("Updated post_tte_win_thresh: %s", paste0(l$post_tte_win_thresh, collapse = ", "))
      
      # for significance testing of a win in the ppos section 
      n_sero_looks <- length(l$looks[l$looks <= l$nmaxsero])
      
      l$post_sero_win_thresh <- seq(from = l$post_sero_win_thresh_start,
                                    to = l$post_sero_win_thresh_end,
                                    length.out = n_sero_looks)
      
      flog.info("Updated post_sero_win_thresh: %s", paste0(l$post_sero_win_thresh, collapse = ", "))

         
    }
    
    if(!is.null(opt$delay)){
      
      l$sero_info_delay <- opt$delay
      
      flog.info("Updated information delay: %s", paste0(l$sero_info_delay, collapse = ", "))
      
    }
    
    
    
    if(!is.null(opt$basesero) | !is.null(opt$trtprobsero)){
      l$baselineprobsero <- opt$basesero
      l$trtprobsero <- opt$trtprobsero
      l$deltaserot3 <- compute_sero_delta(l$baselineprobsero, l$trtprobsero)
      
      flog.info("Updated baselineprobsero: %s", l$baselineprobsero)
      flog.info("Updated trtprobsero: %s", l$trtprobsero)
      flog.info("Updated deltaserot3: %s", l$deltaserot3)
    }
    

    
    if(!is.null(opt$basemediantte) | !is.null(opt$trtmedtte)){
      l$ctl_med_tte <- opt$basemediantte
      l$trt_med_tte <- opt$trtmedtte
      
      l$b0tte <- log(2)/l$ctl_med_tte 
      l$b1tte <- (log(2)/l$trt_med_tte) - l$b0tte
      
      flog.info("Updated ctl_med_tte: %s", l$ctl_med_tte)
      flog.info("Updated trt_med_tte: %s", l$trt_med_tte)
      
      flog.info("Updated b0tte: %s", l$b0tte)
      flog.info("Updated b1tte: %s", l$b1tte)
    }
    
    # write.csv(opt, "test.csv")
 
  }
  
  # colourblind palette
  l$cbPalette <- c("#999999", "#E69F00", "#56B4E9", "#009E73", 
                   "#F0E442", "#0072B2", "#D55E00", "#CC79A7")

  return(l)
}



plot_tte <- function(dt1, cfg, idx = NULL){
  
  if(is.null(idx)){
    idx <- nrow(dt1)
  }
  
  maxmnths1 <-  dt1[idx, accrt] 
  maxmnths2 <-  dt1[idx, accrt] + cfg$max_age_fu_months
  
  pctcen <- 100 * round(prop_censored(dt1, cfg, idx), 1)
  xpctcen <- max(dt1[1:idx, evtt]) - 10
  
  ggplot(dt1[1:idx,]) +
    geom_segment(aes(x = accrt, y = id, xend = evtt, yend = id)) +
    scale_x_continuous("Months")+
    scale_y_continuous("Participant ID")+
    geom_vline(xintercept = maxmnths1 , colour = cfg$cbPalette[2])+
    geom_vline(xintercept = maxmnths2, colour = cfg$cbPalette[2])+
    annotate("text", x = maxmnths1-12, y = idx+25, label = "Last enrollment") +
    annotate("text", x = maxmnths2-10, y = idx+25, label = "Last FU") +
    annotate("text", x = xpctcen, y = 20, label = paste0(pctcen, "% censored")) 
}

# proportion of sample up to idx that will be censored assuming 
# idx is the last participant randomised
prop_censored <- function(dt1, cfg, idx = NULL){
  
  if(is.null(idx)){
    idx <- nrow(dt1)
  }
  
  cen <- ifelse(dt1[c(1:idx), evtt] > dt1[idx, accrt] + cfg$max_age_fu_months, 1, 0)
  mean(cen)
  
}



den_plot1 <- function(a, b, xlim = NULL){
  plot(density(a), xlim = xlim)
  lines(density(b), col = "red")
  abline(v = mean(a))
  abline(v = mean(b), col = "red")
  #legend("topleft", "(x,y)")
  legend("topleft", legend=c("a", "b"),
         col=c("black", "red"), lty=c(1,1), cex=0.8)
}

print_immu_res <- function(m){
  
  df <- as.data.frame(m)
  
  df <- df[, c("idxsim",
               "look", 
               "n_obs",
               "ss_immu",
               "n_max",
               "n_max_sero",
               "i_ppos_n", "i_ppos_max", "i_post_prop_ctl", "i_post_prop_trt",   # immunological
               "stop_v_samp",
               "stop_i_fut")]
  
  df
}

print_clin_res <- function(m){
  
  df <- as.data.frame(m)
  
  df <- df[, c("idxsim",
               "look", 
               "n_obs",
               "ss_clin",
               "n_max",
               "n_max_sero",
               "c_ppos_n","c_ppos_max","c_post_lambda_ctl","c_post_lambda_trt",  # clinical
               "stop_c_fut",
               "stop_c_sup")]
  
  df
}




print_cens_warning <- function(desc, current_interim_mnth, accrt, evtt, age, obs_mnths){
  paste0("Warning 1: unhandled censoring case \n ",
         "(", desc, ")\n",
         "interim month ", current_interim_mnth, "\n",
         "accrual time ", accrt, "\n",
         "event time ", evtt, "\n",
         "age at event time ", evtt + age, "\n",
         "surveillance months \n", paste0(obs_mnths, collapse = ", "))
}

print_cens_help <- function(x, ss, cenx, tx, current_interim_mnth, accrtx, evttx, agex, obs_mnthsx){
  paste0("x...............................", x, "\n",
         "ss..............................", ss, "\n",
         "cen.............................", cenx, "\n",
         "t...............................", tx, "\n",
         "interim month...................", current_interim_mnth, "\n",
         "accrual time....................", accrtx, "\n",
         # months from randomisation to the event
         "evt time........................", evttx , "\n", 
         # evt time plus accrual - 
         "evt time plus accrual...........", evttx + accrtx, "\n",
         # age at randomisation 
         "age at randomisation............", agex, "\n", 
         # age at randomisation plus the duration of time to the event
         "age at event time...............", evttx + agex, "\n", 
         "surveillance months (time relative to start of trial)\n", paste0(obs_mnthsx, collapse = ", "))
}



stop_immu <- function(stop_ven_samp,
                      stop_immu_fut,
                      stop_clin_fut,
                      stop_clin_sup, n_look, n_maxsero){
  
  if(stop_ven_samp){
    return(T)
  }
  
  if(n_look > n_maxsero){
    return(T)
  }
  
  if(stop_clin(stop_immu_fut,
               stop_clin_fut,
               stop_clin_sup)){
    return(T)
  }

  return(F)
}


stop_clin <- function(stop_immu_fut,
                      stop_clin_fut,
                      stop_clin_sup){
  
  if(stop_immu_fut){
    return(T)
  }
  
  if(stop_clin_fut){
    return(T)
  }
  
  if(stop_clin_sup){
    return(T)
  }
  
  return(F)
}

surv_lnorm <-function(tte = 1:100, mu = 3, sig = 1){
  n <- length(tte)
  s <- numeric(n)
  surv <- function(x, mu, sig){
    1 - pnorm(log(tte[x]) - mu)/sig
  }
  s <- unlist(lapply(1:n, surv, mu, sig))
  s
}

mu_of_lognormal <- function(m, upsilon){
  log((m^2) / sqrt(upsilon + (m^2)))
}
sig_of_lognormal <- function(m, upsilon){
  sqrt(log((upsilon/m^2) + 1))
}

# The mean and variance of a lognormal distribution created
# with values mu and sig will be:
m_of_lognormal <- function(mu, sig){
  exp(mu + ((sig^2)/2))
}
upsilon_of_lognormal <- function(mu, sig){
  exp(2*mu + sig^2) * (exp(sig^2) - 1)
}

muformediansurvtime <- function(medtime, sig){
  log(medtime) - sig * qnorm(0.5) 
}

init <- function(){
  ggplot2::theme_set(theme_bw())
  ggplot2::theme_update(legend.position="bottom")
  ggplot2::theme_update(legend.title=element_blank())
  # See http://ggplot2.tidyverse.org/reference/theme.html
  ggplot2::theme_update(text=element_text(size=12,  family="sans"))
  ggplot2::theme_update(axis.text.x=element_text(size=10,  family="sans"))
  ggplot2::theme_update(axis.text.y=element_text(size=10,  family="sans"))
  f.sep <- .Platform$file.sep
}

# logit to p
inv_logit <- function(x){
  return(exp(x)/(1+exp(x)))
}
# p to logit
logit <- function(p){
  return(log(p/(1-p)))
}
prob_to_odd <- function(x){
  return(x/(1-x))
}
odd_to_prob <- function(x){
  return(x/(1+x))
}

get_null_sero <- function(cfgfile = "cfg1.yaml"){
  
  fs0 <- readRDS("fso.RDS")
  
  if(!is.null(fs0)){
    return(fs0)
  }
  
  cfg <- sim_cfg(cfgfile)
  dt1 = gen_dat(cfg)
  
  # obtain data and fit models to save in global scope (prevents recompile)
  dat <- make_standata(formula(cfg$fsero), 
                       data = dt1,
                       family = bernoulli())
  
  fs0 <- stan(file=cfg$seromodfile, 
              data=dat, iter=10, chains=1)
  
  saveRDS(fs0, "fso.RDS")
  
  return(fs0)
}


get_null_tte <- function(cfgfile = "cfg1.yaml"){
  
  ft0 <- readRDS("fto.RDS")
  
  if(!is.null(ft0)){
    return(ft0)
  }
  
  cfg <- sim_cfg(cfgfile)
  dt1 = gen_dat(cfg)
  
  # obtain data and fit models to save in global scope (prevents recompile)
  dat <- make_standata(formula(cfg$ftte), 
                       data = dt1,
                       family = lognormal())
  
  ft0 <- stan(file=cfg$ttemodfile, 
              data=dat, iter=10, chains=1)
  
  saveRDS(ft0, "fto.RDS")
  
  return(ft0)
}



med_surv <- function(eta){
  
  log(2)/eta
  
}

stan_model_workflow <- function(){
  
  # https://cran.r-project.org/web/packages/rstan/vignettes/rstan.html
  # A single call to stan performs all three steps, but they can also be
  # executed one by one (see the help pages for stanc, stan_model, and
  # sampling),
  
  stancode <- 'data {real y_mean;} parameters {real y;} model {y ~ normal(y_mean,1);}'
  mod <- stan_model(model_code = stancode)
  fit <- sampling(mod, data = list(y_mean = 0))
  fit2 <- sampling(mod, data = list(y_mean = 5))
  
}

save_demo_dat <- function(){
  
  cfg <- sim_cfg("cfg1.yaml")
  dt1 = gen_dat(cfg)
  
  saveRDS(dt1, "mydat.RDS")
}

write_mod1 <- function(){
  
  cfg <- sim_cfg()
  dt1 = gen_dat(cfg)
  
  dt1$serot3[1:5] <- NA
  
  mf <- bf(cfg$fsero)
  mp <- get_prior(mf,
                  data = dt1,
                  family = bernoulli())
  
  blm0 <- brms::brm(mf, 
                    data = dt1,
                    family = bernoulli(), 
                    prior = mp,
                    iter = 10,
                    chains = 1, 
                    save_model = "brm1.stan",
                    control = list(max_treedepth = 10))
  # summary(blm0, waic = TRUE)
}


write_mod2 <- function(){
  # , data = dt1, family = lognormal()
  # 
  # 
  
  cfg <- sim_cfg()
  dt1 = gen_dat(cfg)
  mf <- bf(evtt | cens(cen) ~ trt + remote)
  mp <- get_prior(mf,
                  data = dt1,
                  family = lognormal())
  
  blm0 <- brms::brm(mf, 
                    data = dt1,
                    family = lognormal(), 
                    prior = mp,
                    iter = 10,
                    chains = 1, 
                    save_model = "brm2.stan",
                    control = list(max_treedepth = 10))
 
}


check_res <- function(){
  
  
  dfdur <- readRDS("2018_12_19_1633/duration.RDS")
  dfres <- readRDS("2018_12_19_1633/dfresults.RDS")
  dfwarn <- readRDS("2018_12_19_1633/warn.RDS")

  # fek
 
}








plot_surv <- function(e3){
  dfnew = data.frame(trt = 0:1, remote = 0)
  predict(e3, newdata = dfnew, type=c("response"), p = 0.5, se = T)
  
  plot(predict(e3, newdata=list(trt=0, remote = 0),
               type="quantile",
               p=seq(.01,.99,by=.01)),
       seq(.99,.01,by=-.01), col="red", type = "l", xlim = c(0, 100))
  
  lines(predict(e3, newdata=list(trt=1, remote = 0),
                type="quantile",
                p=seq(.01,.99,by=.01)),
        seq(.99,.01,by=-.01), col="blue", type = "l", xlim = c(0, 100))
}



jags_init <- function(d, omit_const = T){
  
  # simulated event times for the rest of the trial
  d$Y <- copy(d$evtt)
  
  total_acc_time <- max(d$accrt) + 1
  
  # If the simulated event time plus the accrual time > total_acc_time then censor
  d$cen <- ifelse(d$Y + (d$accrt/cfg$dayspermonth) >  
                               total_acc_time/cfg$dayspermonth, 1, 0)
  d$Y <- ifelse(d$cen, NA, d$Y)
  d$Y_cen <- ifelse(d$cen, (total_acc_time - d$accrt)/cfg$dayspermonth, 0)
  d$Y_all <- ifelse(!is.na(d$Y), d$Y, d$Y_cen)
  
  dat <- list(Y = d$Y,
               Y_cen = d$Y_cen,
               cen = as.logical(d$cen),
               trt = d$trt,
               remote = d$remote)
  if(omit_const == F){
    dat$N = length(dat$Y)
  }
  
  
  init_Y <- rep(NA, length(d$cen))
  init_Y[dat$cen] <- dat$Y_cen[dat$cen]+1
  myinits <- list( 'Y' = init_Y,
          'tau' = runif(1),
          'b0' = rnorm(1),
          'b1' = rnorm(1))
  
  return(list(inits = myinits,
              dat = dat))
}

tte_suff_stats <- function(obst, trt, cen, n){
  
  obst <- obst[1:n]
  trt <- trt[1:n]
  cen <- cen[1:n]
  
  n_uncen_0 <- sum(1-cen[trt == 0])
  n_uncen_1 <- sum(1-cen[trt == 1])
  
  tot_obst_0 <- sum(obst[trt == 0])
  tot_obst_1 <- sum(obst[trt == 1])
  
  
  return(list(n_uncen_0 = n_uncen_0,
              n_uncen_1 = n_uncen_1,
              tot_obst_0 = tot_obst_0,
              tot_obst_1 = tot_obst_1))
}

plot_tte_hist_dat <- function(obst, trt, n){
  
  obst <- obst[1:n]
  trt <- trt[1:n]
  o0 <- obst[trt == 0]
  o1 <- obst[trt == 1]
  
  par(mfrow = c(1, 2))
  hist(o0, probability = T, main = "CTL evtt")
  abline(v = 30, col = "red", lwd = 2)
  abline(v = median(o0), col = "blue", lwd = 2)
  hist(o1, probability = T, main = "TRT evtt")
  abline(v = 35, col = "red", lwd = 2)
  abline(v = median(o1), col = "blue", lwd = 2)
  par(mfrow = c(1, 1))
}


plot_tte_hist <- function(m){
  
  par(mfrow = c(2, 2))
  
  med0 <- log(2)/m[, 1]
  med1 <- log(2)/m[, 2]
  
  hist(med0, probability = T, main = "")
  abline(v = 30, col = "red", lwd = 2)
  abline(v = median(med0), col = "blue", lwd = 2)
  hist(med1, probability = T, main = "")
  abline(v = 35, col = "red", lwd = 2)
  abline(v = median(med1), col = "blue", lwd = 2)
  hist(m[, 3], probability = T, main = "")
  abline(v = 35/30, col = "red", lwd = 2)
  abline(v = median(med1/med0) , col = "blue", lwd = 2)
  plot(c(0, 10), c(0, 10))
  legend(0, 5, legend=c("true med", "sample med"),
         col=c("red", "blue"), lty=1:2, cex=0.8)
  par(mfrow = c(1, 1))
}

plot_tte_meds_hist <- function(m, tmed0, tmed1){
  
  par(mfrow = c(2, 2))
  med0 <- m[, 1]
  med1 <- m[, 2]
  hist(med0, probability = T, main = "")
  abline(v = tmed0, col = "red", lwd = 2)
  abline(v = median(med0, na.rm = T), col = "blue", lwd = 2)
  hist(med1, probability = T, main = "")
  abline(v = tmed1, col = "red", lwd = 2)
  abline(v = median(med1, na.rm = T), col = "blue", lwd = 2)
  hist(m[, 3], probability = T, main = "")
  abline(v = tmed1/tmed0, col = "red", lwd = 2)
  abline(v = median(med1/med0) , col = "blue", lwd = 2)
  plot(c(0, 10), c(0, 10))
  legend(0, 5, legend=c("true med", "sample med"),
         col=c("red", "blue"), lty=1:2, cex=0.8)
  par(mfrow = c(1, 1))
}

test_gammy <- function(){
  set.seed(4343)
  n <- 1000
  a <- 1
  b <- 10
  
  hist(rgamma(n, a, b))
  
  
  x <- seq(from = 0.0, to = 1.5, length.out = 1000)
  y <- dgamma(x, shape = a, rate = b)
  
  
  plot(x, y, type = "l")
  
  # 0.009902103
  
  test <- rgamma(1000, a, b)
  mean(test)
  hist(test)
  
  
  y2 <- rcpp_gamma(n, a, 1/b)
  
  hist(y2, probability = T)
  lines(x, y, col = "red", lwd = 3)
  
  # 48 36 
  # 2070 2400
  
  c <- 1/b
  y2 <- rcpp_gamma(n, a, c)
  
  hist(y2, probability = T)  
  
  
  y3 <- rcpp_gamma(n, a + 48, c / (1 + c * 2000))
  hist(y3, probability = T)  
  
  y3 <- rcpp_gamma(n, a + 36, c / (1 + c * 2400))
  hist(y3, probability = T)   
  
  
  hist(rcpp_gamma(1000, 1 + 48, (1/20) / (1 + (1/20) * 2000)))
  
}

