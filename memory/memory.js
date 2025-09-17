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

var memory_ratings = {
    type: jsPsychSurvey,
    survey_json: function () {
        return {
            goNextPageAutomatic: false,
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
                        {
                            type: "html",
                            name: "Stimulus",
                            html:
                                "<img src='" +
                                "stimuli/" +
                                jsPsych.evaluateTimelineVariable("Item") +
                                "' style='max-width:80vw; max-height:50vh; width:auto; height:auto; display:block; margin:0 auto; border-radius:4px;'>",
                        },
                        {
                            type: "slider",
                            name: "Beauty2",
                            title: "This artwork is...",
                            isRequired: true,
                            min: -3,
                            max: 3,
                            step: 0.01,
                            customLabels: [
                                {
                                    value: -3,
                                    text: "Ugly",
                                },
                                {
                                    value: 3,
                                    text: "Beautiful",
                                },
                            ],
                            // defaultValue: 0,
                        },
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
                            title: "In the previous study, the artwork was labelled as...",
                            description: "What was the label preceding the artwork in the first stage of the study",
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
                        {
                            type: "slider",
                            name: "PerceivedArtificiality",
                            title: "I could easily believe that this artwork was created by AI",
                            isRequired: true,
                            visibleIf: "{Recognition} = 'No'",
                            min: 0,
                            max: 1,
                            step: 0.1,
                            customLabels: [
                                {
                                    value: 0,
                                    text: "Not at all",
                                },
                                {
                                    value: 1,
                                    text: "Very much",
                                },
                            ],
                            // defaultValue: 0,
                        },
                    ],
                },
            ],
        }
    },
    data: {
        screen: "memory_ratings",
    },
}

var memory_phase = {
    timeline_variables: shuffleArray(stimuli_list).slice(0, 4), // <---------------------------- TODO: remove the extra slicing added for testing
    timeline: [memory_ratings],
}
