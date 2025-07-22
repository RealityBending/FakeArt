library(jsonlite)
library(progress)

options(warn = 2) # Stop on warnings

path <- "C:/Users/domma/Box/Data/FictionArt/"
# path <- "C:/Users/maisi/Box/FictionArt/

# Run loop ----------------------------------------------------------------

files <- list.files(path, full.names = TRUE, pattern = "*.csv")


# Progress bar
progbar <- progress_bar$new(total = length(files))

alldata <- data.frame()
alldata_task <- data.frame()
for (file in files) {
  progbar$tick()
  rawdata <- read.csv(file)

  # Initialize participant-level data
  dat <- rawdata[rawdata$screen == "browser_info", ]

  if (is.na(dat$prolific_id) && is.na(dat$researcher)) {
    print(paste0("skip (no 'exp' URLvar): ", gsub(path, "", file)))
    next
  }

  participant <- gsub(".csv", "", rev(strsplit(file, "/")[[1]])[1]) # Filename without extension

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
    data_ppt$ID <- NA
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
  # data_ppt$Education <- ifelse(data_ppt$Education %in% c("HND (college)"), "High school", data_ppt$Education)

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

  vviq <- jsonlite::fromJSON(rawdata[
    rawdata$screen == "questionnaire_vviq",
    "response"
  ])

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
    if (any(grepl("labels did not match", fb$FeedbackFiction3))) {
      data_ppt$Feedback_LabelsNotMatched <- TRUE
    }
    if (any(grepl("labels were reversed", fb$FeedbackFiction3))) {
      data_ppt$Feedback_LabelsReversed <- TRUE
    }
    if (any(grepl("all images were real", fb$FeedbackFiction3))) {
      data_ppt$Feedback_LabelsAllReal <- TRUE
    }
    if (any(grepl("all images were AI-generated", fb$FeedbackFiction3))) {
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
      dat$question1 <- NULL # TODO: change to "Instructions" for new ppts
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

  if (nrow(data_task) != 64) {
    print(paste0("No task data for: ", participant))
    next
  }

  alldata <- rbind(data_ppt, alldata)
  alldata_task <- rbind(alldata_task, data_task)
}

# table(alldata$Education)
# table(alldata$Ethnicity)
# table(alldata$Recruitment)

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
  stop("Duplicates deteccted!")
}

# Anonymize ---------------------------------------------------------------
alldata$Prolific_ID <- NULL
alldata$Reward <- NULL

# Generate IDs
ids <- paste0("S", format(sprintf("%03d", 1:nrow(alldata))))
# Sort Participant according to date and assign new IDs
names(ids) <- alldata$Participant[order(alldata$Experiment_StartDate)]
# Replace IDs
alldata$Participant <- ids[alldata$Participant]


# Save --------------------------------------------------------------------
# restore default warnings settings
options(warn = 0)

write.csv(alldata, "../data/rawdata_participants.csv", row.names = FALSE)
