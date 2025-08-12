library(jsonlite)
library(progress)

options(warn = 2) # Stop on warnings

path <- "C:/Users/domma/Box/Data/FictionArt/"
# path <- "C:/Users/dmm56/Box/Data/FictionArt/"


datastims <- read.csv("../experiment/stimuli/stimuli_data.csv")
names(datastims) <- gsub("Familarity_Mean_All", "Norms_Familiarity", names(datastims))
names(datastims) <- gsub("Complexity_Mean_All", "Norms_Complexity", names(datastims))
names(datastims) <- gsub("Liking_Mean_All", "Norms_Liking", names(datastims))
names(datastims) <- gsub("Valence_Mean_All", "Norms_Valence", names(datastims))
names(datastims) <- gsub("Arousal_Mean_All", "Norms_Arousal", names(datastims))



# Run loop ----------------------------------------------------------------

files <- list.files(path, full.names = TRUE, pattern = "*.csv")


# Progress bar
progbar <- progress_bar$new(total = length(files))

alldata <- data.frame()
alldata_task <- data.frame()
alldata_gaze <- data.frame()


for (file in files) {
  progbar$tick()
  rawdata <- read.csv(file)

  participant <- gsub(".csv", "", rev(strsplit(file, "/")[[1]])[1]) # Filename without extension

  # Initialize participant-level data
  dat <- rawdata[rawdata$screen == "browser_info", ]

  if (is.na(dat$prolific_id) && is.na(dat$researcher)) {
    print(paste0("skip (no 'exp' URLvar): ", gsub(path, "", file)))
    next
  }

  if(dat$researcher %in% c("testp", "test")) {
    next # Skip test participants
  }

  data_ppt <- data.frame(
    Participant = participant,
    Recruitment = dat$researcher,
    Experiment_StartDate = as.POSIXct(
      paste(dat$date, dat$time),
      format = "%d/%m/%Y %H:%M:%S"
    ),
    Experiment_Duration = max(rawdata$time_elapsed) / 1000 / 60,
    Browser_Version = paste(dat$browser, dat$browser_version),
    Mobile = dat$mobile,
    Platform = dat$os,
    Screen_Width = dat$screen_width,
    Screen_Height = dat$screen_height
  )

  if (data_ppt$Recruitment == "prolific") {
    data_ppt$ID <- dat$prolific_id
  } else if (data_ppt$Recruitment == "SONA") {
    data_ppt$ID <- dat$sona_id
  } else {
    data_ppt$ID <- data_ppt$Recruitment
  }

  data_ppt$Reward <- rawdata[rawdata$screen == "demographics_debrief", "Reward"]

  # Demographics
  resp <- jsonlite::fromJSON(
    rawdata[rawdata$screen == "demographic_questions", ]$response
  )

  data_ppt$Gender <- ifelse(!is.null(resp$Gender), resp$Gender, NA)
  data_ppt$Age <- ifelse(!is.null(resp$Age), resp$Age, NA)

  # Education
  data_ppt$Education <- ifelse(
    resp$Education == "other",
    resp$`Education-Comment`,
    resp$Education
  )
  data_ppt$Education <- ifelse(data_ppt$Education %in% c("Nvq level 3"), "High school", data_ppt$Education)

  data_ppt$Student <- ifelse(!is.null(resp$Student), resp$Student, NA)
  data_ppt$Country <- ifelse(!is.null(resp$Country), resp$Country, NA)

  # Ethnicity
  data_ppt$Ethnicity <- ifelse(!is.null(resp$Ethnicity), resp$Ethnicity, NA)
  data_ppt$Ethnicity <- ifelse(
    !is.na(resp$Ethnicity) && resp$Ethnicity == "other",
    resp$`Ethnicity-Comment`,
    resp$Ethnicity
  )
  # data_ppt$Ethnicity <- ifelse(data_ppt$Ethnicity %in% c("Southern European", "White European"), "White", data_ppt$Ethnicity)
  data_ppt$Ethnicity <- ifelse(
    data_ppt$Ethnicity %in% c("Prefer not to say"),
    NA,
    data_ppt$Ethnicity
  )

  # Experiment Feedback
  feedback <- jsonlite::fromJSON(rawdata[
    rawdata$screen == "experiment_feedback",
    "response"
  ])
  data_ppt$Experiment_Enjoyment <- ifelse(
    is.null(feedback$Feedback_Enjoyment),
    NA,
    feedback$Feedback_Enjoyment
  )
  data_ppt$Experiment_Quality <- ifelse(
    is.null(feedback$Feedback_Quality),
    NA,
    feedback$Feedback_Quality
  )
  data_ppt$Experiment_Feedback <- ifelse(
    is.null(feedback$Feedback_Text),
    NA,
    feedback$Feedback_Text
  )

  # Questionnaires
  mint <- as.data.frame(jsonlite::fromJSON(rawdata[
    rawdata$screen == "questionnaire_mint",
    "response"
  ]))
  data_ppt <- cbind(data_ppt, mint)
  data_ppt$Duration_MINT <- as.numeric(rawdata[
    rawdata$screen == "questionnaire_mint",
    "rt"
  ]) /
    1000 /
    60

  bait <- as.data.frame(jsonlite::fromJSON(rawdata[
    rawdata$screen == "questionnaire_bait",
    "response"
  ]))
  data_ppt <- cbind(data_ppt, bait)
  data_ppt$Duration_BAIT <- as.numeric(rawdata[
    rawdata$screen == "questionnaire_bait",
    "rt"
  ]) /
    1000 /
    60
  if(!"BAIT_AI_Use" %in% names(bait)) {
    data_ppt$BAIT_AI_Use <- NA
  }

  phq4 <- jsonlite::fromJSON(rawdata[
    rawdata$screen == "questionnaire_phq4",
    "response"
  ])
  phq4$instructions_phq4 <- NULL
  data_ppt <- cbind(data_ppt, as.data.frame(phq4))

  erns <- jsonlite::fromJSON(rawdata[
    rawdata$screen == "questionnaire_erns",
    "response"
  ])
  erns$instructions_erns <- NULL
  data_ppt <- cbind(data_ppt, as.data.frame(erns))
  data_ppt$Duration_ERNS <- as.numeric(rawdata[
    rawdata$screen == "questionnaire_erns",
    "rt"
  ]) /
    1000 /
    60

  vviq <- jsonlite::fromJSON(rawdata[
    rawdata$screen == "questionnaire_vviq",
    "response"
  ])
  vviq$instructions_vviq <- NULL
  vviq <- lapply(vviq, \(x) {
    x <- ifelse(grepl("No image", x), 0, x)
    x <- ifelse(grepl("Dim and vague", x), 1, x)
    x <- ifelse(grepl("Moderately realistic", x), 2, x)
    x <- ifelse(grepl("Realistic and reasonably", x), 3, x)
    x <- ifelse(grepl("Perfectly realistic", x), 4, x)
    x
  })
  data_ppt <- cbind(data_ppt, as.data.frame(vviq))
  data_ppt$Duration_VVIQ <- as.numeric(rawdata[
    rawdata$screen == "questionnaire_vviq",
    "rt"
  ]) /
    1000 /
    60


  # Task Feedback
  data_ppt$Duration_TaskInstructions1 <- as.numeric(rawdata[
    rawdata$screen == "fiction_instructions1",
    "rt"
  ]) /
    1000 /
    60
  data_ppt$Duration_TaskInstructions2 <- as.numeric(rawdata[
    rawdata$screen == "fiction_instructions2",
    "rt"
  ]) /
    1000 /
    60

  fb <- jsonlite::fromJSON(rawdata[
    rawdata$screen == "fiction_feedback1",
    "response"
  ])

  data_ppt$Feedback_MoreBeautifulAI <- FALSE
  data_ppt$Feedback_LessBeautifulAI <- FALSE
  data_ppt$Feedback_BigDifferenceRealAI <- FALSE
  data_ppt$Feedback_SmallDifferenceRealAI <- FALSE
  data_ppt$Feedback_NoDifferenceRealAI <- FALSE
  data_ppt$Feedback_BadForgeries <- FALSE
  data_ppt$Feedback_GoodForgeries <- FALSE
  data_ppt$Feedback_LabelsNoAttention <- FALSE
  data_ppt$Feedback_LabelsPaidAttention <- FALSE
  data_ppt$Feedback_LabelsNotMatched <- FALSE
  data_ppt$Feedback_LabelsReversed <- FALSE
  data_ppt$Feedback_LabelsAllReal <- FALSE
  data_ppt$Feedback_LabelsAllAI <- FALSE
  data_ppt$Feedback_ConfidenceReal <- NA
  data_ppt$Feedback_ConfidenceAI <- NA
  if ("FeedbackFiction1" %in% names(fb)) {
    if (any(grepl("more beautiful", fb$FeedbackFiction1))) {
      data_ppt$Feedback_MoreBeautifulAI <- TRUE
    }
    if (any(grepl("less beautiful", fb$FeedbackFiction1))) {
      data_ppt$Feedback_LessBeautifulAI <- TRUE
    }
    if (any(grepl("was obvious", fb$FeedbackFiction1))) {
      data_ppt$Feedback_BigDifferenceRealAI <- TRUE
    }
    if (any(grepl("was subtle", fb$FeedbackFiction1))) {
      data_ppt$Feedback_SmallDifferenceRealAI <- TRUE
    }
    if (any(grepl("any difference", fb$FeedbackFiction1))) {
      data_ppt$Feedback_NoDifferenceRealAI <- TRUE
    }
  }
  if ("FeedbackFiction2" %in% names(fb)) {
    if (any(grepl("less well executed", fb$FeedbackFiction2))) {
      data_ppt$Feedback_BadForgeries <- TRUE
    }
    if (any(grepl("very convincing", fb$FeedbackFiction2))) {
      data_ppt$Feedback_GoodForgeries <- TRUE
    }
  }
  if ("FeedbackFiction3" %in% names(fb)) {
    if (any(grepl("didn't really pay attention", fb$FeedbackFiction3))) {
      data_ppt$Feedback_LabelsNoAttention <- TRUE
    }
    if (any(grepl("watched each painting", fb$FeedbackFiction3))) {
      data_ppt$Feedback_LabelsPaidAttention <- TRUE
    }
    if (any(grepl("not always match", fb$FeedbackFiction3))) {
      data_ppt$Feedback_LabelsNotMatched <- TRUE
    }
    if (any(grepl("labels were reversed", fb$FeedbackFiction3))) {
      data_ppt$Feedback_LabelsReversed <- TRUE
    }
    if (any(grepl("images were real", fb$FeedbackFiction3))) {
      data_ppt$Feedback_LabelsAllReal <- TRUE
    }
    if (any(grepl("images were AI-generated", fb$FeedbackFiction3))) {
      data_ppt$Feedback_LabelsAllAI <- TRUE
    }
  }
  if (!is.null(fb$FeedbackFiction_ConfidenceReal)) {
    data_ppt$Feedback_ConfidenceReal <- fb$FeedbackFiction_ConfidenceReal
  }
  if (!is.null(fb$FeedbackFiction_ConfidenceFake)) {
    data_ppt$Feedback_ConfidenceAI <- fb$FeedbackFiction_ConfidenceFake
  }

  # Task
  cue1 <- rawdata[rawdata$screen == "fiction_cue", ]
  isi1 <- rawdata[rawdata$screen == "fiction_fixation1b", ]
  img1 <- rawdata[rawdata$screen == "fiction_image1", ]
  resp1 <- sapply(
    rawdata[rawdata$screen == "fiction_ratings1", "response"],
    \(x) as.data.frame(jsonlite::fromJSON(x)),
    simplify = FALSE,
    USE.NAMES = FALSE
  )
  resp1 <- do.call(rbind, resp1)
  img2 <- rawdata[rawdata$screen == "fiction_image2", ]
  resp2 <- sapply(
    rawdata[rawdata$screen == "fiction_ratings2", "response"],
    \(x) {
      dat <- jsonlite::fromJSON(x)
      dat$Instructions <- NULL
      as.data.frame(dat)
    },
    simplify = FALSE,
    USE.NAMES = FALSE
  )
  resp2 <- do.call(rbind, resp2)

  # Make sure no skipping occured
  if (!all(img1$response == "null")) {
    print("Responses not all null!")
    break
  }

  data_task <- data.frame(
    Participant = participant,
    Condition = cue1$condition,
    Item = img1$item,
    Trial1 = img1$trial_number,
    CueColor = tools::toTitleCase(cue1$color),
    ScreenWidth = img1$window_width,
    ScreenHeight = img1$window_height,
    Beauty = resp1$Beauty,
    Valence = resp1$Valence,
    Meaning = resp1$Meaning,
    Worth = resp1$Worth
  ) |>
    merge(
      data.frame(
        Item = img2$item,
        Trial2 = img2$trial_number,
        Reality = resp2$Reality,
        Authenticity = resp2$Authenticity
      ),
      sort = FALSE
    )

  # Re-map to values in dollars
  # data_task$Worth <- ifelse(data_task$Worth == 1, 10, data_task$Worth)
  # data_task$Worth <- ifelse(data_task$Worth == 2, 100, data_task$Worth)
  # data_task$Worth <- ifelse(data_task$Worth == 3, 1000, data_task$Worth)
  # data_task$Worth <- ifelse(data_task$Worth == 4, 10000, data_task$Worth)
  # data_task$Worth <- ifelse(data_task$Worth == 5, 100000, data_task$Worth)

  if (nrow(data_task) != 64) {
    print(paste0("No task data for: ", participant))
    next
  }

  # Merge with stim info
  data_task <- merge(data_task, datastims[!names(datastims) %in% c("Date", "Width", "Height")])

  # Eye tracking
  data_ppt$Eyetracking_Validation1 <- NA
  data_ppt$Eyetracking_Validation2 <- NA

  calibration <- rawdata[rawdata$screen == "eyetracking_validation_run", ]
  if(nrow(calibration) > 0) {
    calibration <- tail(calibration$percent_in_roi, 2) # Take last 2
    calibration <- sapply(calibration, \(x) {
      scores <- jsonlite::fromJSON(x)
      mean(scores)
    }, USE.NAMES = FALSE)
    if(!"numeric" %in% class(calibration[1])) {
      stop("Calibration data is not numeric!")
    }
    data_ppt$Eyetracking_Validation1 <- calibration[1]
    data_ppt$Eyetracking_Validation2 <- calibration[2]

    gaze_isi <- lapply(isi1$webgazer_data, \(x) {
      as.data.frame(jsonlite::fromJSON(x))
    })
    gaze_isi_stim <- lapply(isi1$webgazer_targets, \(x) {
      as.data.frame(jsonlite::fromJSON(x)$`#jspsych-html-keyboard-response-stimulus`)
    })
    gaze_img <- lapply(img1$webgazer_data, \(x) {
      as.data.frame(jsonlite::fromJSON(x))
    })
    gaze_img_stim <- lapply(img1$webgazer_targets, \(x) {
      as.data.frame(jsonlite::fromJSON(x)$`#jspsych-image-keyboard-response-stimulus`)
    })

    # It seems likely that in the WebGazer extension for jsPsych, the (0,0)
    # coordinates correspond to the top-left corner of the viewport, based on
    # standard web coordinate systems. Research suggests x increases to the
    # right and y increases downward.

    data_gaze <- data.frame()
    for(i in 1:64) {
      if(nrow(gaze_isi[[i]]) > 0) {
        gaze_isi[[i]]$Item <- data_task[i, "Item"]
        gaze_isi[[i]]$Stimulus <- "Fixation"
        gaze_isi[[i]]$x <- gaze_isi[[i]]$x
        gaze_isi[[i]]$y <- gaze_isi[[i]]$y
        gaze_isi[[i]]$ScreenWidth <- data_task[i, "ScreenWidth"]
        gaze_isi[[i]]$ScreenHeight <- data_task[i, "ScreenHeight"]
        gaze_isi[[i]]$Stimulus_left <- gaze_isi_stim[[i]]$x
        gaze_isi[[i]]$Stimulus_top <- gaze_isi_stim[[i]]$top
        gaze_isi[[i]]$Stimulus_height <- gaze_isi_stim[[i]]$height
        gaze_isi[[i]]$Stimulus_width <- gaze_isi_stim[[i]]$width
        data_gaze <- rbind(data_gaze, gaze_isi[[i]])
      }

      if(nrow(gaze_img[[i]]) > 0) {
        gaze_img[[i]]$Item <- data_task[i, "Item"]
        gaze_img[[i]]$Stimulus <- "Image"
        gaze_img[[i]]$x <- gaze_img[[i]]$x
        gaze_img[[i]]$y <- gaze_img[[i]]$y
        gaze_img[[i]]$ScreenWidth <- data_task[i, "ScreenWidth"]
        gaze_img[[i]]$ScreenHeight <- data_task[i, "ScreenHeight"]
        gaze_img[[i]]$Stimulus_left <- gaze_img_stim[[i]]$x
        gaze_img[[i]]$Stimulus_top <- gaze_img_stim[[i]]$top
        gaze_img[[i]]$Stimulus_height <- gaze_img_stim[[i]]$height
        gaze_img[[i]]$Stimulus_width <- gaze_img_stim[[i]]$width
        data_gaze <- rbind(data_gaze, gaze_img[[i]])
      }
    }
    if(nrow(data_gaze) > 0) {
      data_gaze$t <- data_gaze$t / 1000 # Convert to seconds
      data_gaze$Participant <- participant
    }
  }


  # Save all
  alldata <- rbind(data_ppt, alldata)
  alldata_task <- rbind(alldata_task, data_task)
  alldata_gaze <- rbind(alldata_gaze, data_gaze)
}

# table(alldata$Education)
# table(alldata$Ethnicity)
# table(alldata$Recruitment)

alldata[c("Duration_ERNS", "Duration_VVIQ", "Experiment_Duration")]

hist(alldata$Experiment_Duration, breaks = 30)

# Should we re-map the Worth values? -----------------------------------
# Re-map to values in dollars
# alldata_task$Worth2 <- ifelse(alldata_task$Worth == 1, 10, alldata_task$Worth)
# alldata_task$Worth2 <- ifelse(alldata_task$Worth2 == 2, 100, alldata_task$Worth2)
# alldata_task$Worth2 <- ifelse(alldata_task$Worth2 == 3, 1000, alldata_task$Worth2)
# alldata_task$Worth2 <- ifelse(alldata_task$Worth2 == 4, 10000, alldata_task$Worth2)
# alldata_task$Worth2 <- ifelse(alldata_task$Worth2 == 5, 100000, alldata_task$Worth2)
#
# library(tidyverse)
#
# t <- as.data.frame(table(alldata_task$Worth))
# cor.test(as.numeric(as.character(t$Var1)), t$Freq)
# t <- as.data.frame(table(log1p(alldata_task$Worth2)))
# cor.test(as.numeric(as.character(t$Var1)), t$Freq)
#
# ggplot(alldata_task, aes(x=Worth)) +
#   geom_bar() +
#   geom_abline()
# ggplot(alldata_task, aes(x=log1p(Worth2))) +
#   geom_bar()
# ggplot(alldata_task, aes(x=Worth2)) +
#   geom_bar() +
#   scale_x_continuous(transform = "log1p", breaks = c(0, 10, 100, 1000, 10000, 100000))
# ggplot(alldata_task, aes(x=Worth, y=Beauty)) +
#   geom_smooth(method = "lm") +
#   geom_jitter(height=0)
# ggplot(alldata_task, aes(x=Worth2, y=Beauty)) +
#   geom_smooth(method = "lm") +
#   geom_jitter(height=0) +
#   scale_x_continuous(transform = "log1p", breaks = c(0, 10, 100, 1000, 10000, 100000))
# summary(lm(Beauty ~ Worth, data = alldata_task))
# summary(lm(Beauty ~ log1p(Worth2), data = alldata_task))

# Attention checks --------------------------------------------------------
checks <- data.frame(
  MINT = 1 - alldata$MINT_AttentionCheck / 6,
  BAIT = alldata$BAIT_AttentionCheck / 6
)
checks$Score <- rowMeans(checks)
checks$ID <- alldata$ID
checks$Experiment_Duration <- alldata$Experiment_Duration
checks$Reward <- alldata$Reward
checks <- checks[!is.na(checks$ID), ]
checks <- checks[order(checks$Score, decreasing = TRUE), ]
# checks
# checks[checks$ID=="5ff454f2f0b5ed607169fba6", ]

# Hi, unfortunately, we can't find your data (and Prolific information suggests that you did not finish the experiment?) Did anything go wrong? Sorry for that!

# Make sure there are no duplicates
if (nrow(alldata[duplicated(alldata), ]) > 0) {
  stop("Duplicates detected!")
}


# Outlier (based on feedback) ------------------------------------------------------
# "fghgugdaz0 thought phase 2 was a memory task"
# alldata_task[alldata_task$Participant == "fghgugdaz0", "Reality"] <- NA
# alldata_task[alldata_task$Participant == "fghgugdaz0", "Authenticity"] <- NA

# Anonymize ---------------------------------------------------------------
alldata$ID <- NULL
alldata$Reward <- NULL

# Generate IDs
ids <- paste0("S", format(sprintf("%03d", 1:nrow(alldata))))
# Sort Participant according to date and assign new IDs
names(ids) <- alldata$Participant[order(alldata$Experiment_StartDate)]
# Replace IDs
alldata$Participant <- ids[alldata$Participant]
alldata_task$Participant <- ids[alldata_task$Participant]
alldata_gaze$Participant <- ids[alldata_gaze$Participant]


# Save --------------------------------------------------------------------
# restore default warnings settings
options(warn = 0)

write.csv(alldata, "../data/rawdata_participants.csv", row.names = FALSE)
write.csv(alldata_task, "../data/rawdata_task.csv", row.names = FALSE)
write.csv(alldata_gaze, "../data/rawdata_eyetracking.csv", row.names = FALSE)


# PILOT STIMULI SELECTION -------------------------------------------------

library(tidyverse)

alldata_task |>
  datawizard::normalize(select = c("Beauty", "Valence", "Meaning", "Worth", "Reality", "Authenticity")) |>
  mutate(Item = fct_reorder(Item, Reality)) |>
  pivot_longer(c(Beauty, Valence, Meaning, Worth, Reality, Authenticity),
               names_to = "Variable", values_to = "Value") |>
  filter(Variable %in% c("Beauty", "Reality", "Authenticity")) |>
  ggplot(aes(y = Item, x = Value, fill = Style)) +
  ggdist::stat_slab(normalize = "all", height = 3, color = "black") +
  facet_wrap(~ Variable, scales = "free_x")
# unique(alldata_task[alldata_task$Item == "10319.jpg", "Artist"])


