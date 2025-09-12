function shuffleArray(array) {
    for (let i = array.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1))
        ;[array[i], array[j]] = [array[j], array[i]]
    }
    return array
}

var memory_trialnumber = 1

var memory_preloadstims = {
    type: jsPsychPreload,
    images: stimuli_list.map((a) => "stimuli/" + a.Item),
    message: "Please wait while the experiment is loading in (it can take a few minutes).",
}

var memory_fixation = {
    type: jsPsychHtmlKeyboardResponse,
    stimulus: "<div  style='font-size:500%; position:fixed; text-align: center; top:50%; bottom:50%; right:20%; left:20%'>+</div>",
    choices: ["s"],
    trial_duration: 750,
    save_trial_parameters: { trial_duration: true },
    data: { screen: "memory_fixation" },
}

var memory_showimage = {
    type: jsPsychImageKeyboardResponse,
    stimulus: function () {
        return "stimuli/" + jsPsych.evaluateTimelineVariable("Item")
    },
    stimulus_width: function () {
        let ratio = jsPsych.evaluateTimelineVariable("Width") / jsPsych.evaluateTimelineVariable("Height")
        return Math.round(Math.min(0.9 * window.innerHeight * ratio, 0.9 * window.innerWidth))
    },

    stimulus_height: function () {
        let ratio = jsPsych.evaluateTimelineVariable("Width") / jsPsych.evaluateTimelineVariable("Height")
        return Math.round(Math.min((0.9 * window.innerWidth) / ratio, 0.9 * window.innerHeight))
    },
    trial_duration: 2000,
    choices: ["s"],
    save_trial_parameters: { trial_duration: true },
    data: function () {
        return {
            screen: "memory_image",
            trial_number: memory_trialnumber,
            item: jsPsych.evaluateTimelineVariable("Item"),
        }
    },
    on_finish: function () {
        memory_trialnumber += 1
    },
}

var memory_ratings = {
    type: jsPsychSurvey,
    survey_json: {
        goNextPageAutomatic: true,
        showQuestionNumbers: false,
        completeText: "Continue",
        showNavigationButtons: true,
        title: function () {
            return "Rating - " + Math.round(((memory_trialnumber - 1) / stimuli_list.length) * 100) + "%"
        },
        description: "Do you recognise the artwork?",
        pages: [
            {
                elements: [
                    // {
                    //     type: "html",
                    //     name: "Stimulus",
                    //     html: "<p> IMAGE </p>",
                    // },
                    {
                        type: "rating",
                        name: "SelfRelevance",
                        title: "This painting is personally relevant...",
                        description: "It relates to my personality, interests, or reminds me of events in my life",
                        isRequired: true,
                        rateMin: 0,
                        rateMax: 6,
                        minRateDescription: "Not at all",
                        maxRateDescription: "Very much",
                    },

                    {
                        type: "radiogroup",
                        name: "Recognition",
                        title: "I recognise this artwork from the previous study",
                        isRequired: true,
                        choices: ["Yes", "No"],
                    },

                    {
                        type: "rating",
                        name: "SourceCondition",
                        title: "In the previous study, we labelled the artwork as...",
                        isRequired: true,
                        visibleIf: "{Recognition} = 'Yes'",
                        displayMode: "buttons",
                        rateValues: ["Original", "AI-Generated", "Human Forgery"],
                    },

                    {
                        type: "radiogroup",
                        name: "SourceBelief",
                        title: "In the previous study, I answered that the artwork was...",
                        isRequired: true,
                        visibleIf: "{Recognition} = 'Yes'",
                        choices: ["Human Original", "Human Forgery", "AI Original", "AI Copy"],
                    },
                ],
            },
        ],
    },
    data: {
        screen: "memory_ratings",
    },
}

var memory_phase = {
    timeline_variables: shuffleArray(stimuli_list).slice(0, 2), // <---------------------------- TODO: remove the extra slicing added for testing
    timeline: [memory_fixation, memory_showimage, memory_ratings],
}
