// Questionnaire instructions ================================================================================================
var questionnaires_instructions0 = {
    type: jsPsychHtmlButtonResponse,
    stimulus:
        "<h1>Part 3/4</h1>" +
        "<p>Great! We will continue with a series of questionnaires and a visualization task.<br>Again, it is important that you answer truthfully. Please read the statements carefully and answer according to what describe you the best.</p>",
    choices: ["Continue"],
    data: { screen: "part2_instructions" }, // why is this label needed?
}


// Generation code ==========================================================================================================
// Convenience function to shuffle an object (used internally)
function shuffleObject(obj) {
    const entries = Object.entries(obj)
    for (let i = entries.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1))
        ;[entries[i], entries[j]] = [entries[j], entries[i]]
    }
    return Object.fromEntries(entries)
}


// PHQ-4 ====================================================================================================================
// The 4 item patient health questionnaire for anxiety and depression (Kroenke et al., 2009)
// total score, sum of all items
// scores are rated as normal (0-2), mild (3-5), moderate (6-8), severe (9-12)
// total score >= 3 for first two items suggests anxiety, total score >= 3 for last two items suggests depression

const items_phq4 = {
    PHQ4_Anxiety_1: "Feeling nervous, anxious or on edge",
    PHQ4_Anxiety_2: "Not being able to stop or control worrying",
    PHQ4_Depression_3: "Feeling down, depressed, or hopeless",
    PHQ4_Depression_4: "Little interest or pleasure in doing things",
}

const instructions_phq4 = {
    type: "html",
    name: "instructions_phq4",
    html: "<p>Over the <b>last 2 weeks</b>, how often have you been bothered by the following problems?</p>",
}

function make_phq4(items, required = false) {
    items = shuffleObject(items)
    questions = [instructions_phq4]

    // Make questions
    for (const key of Object.keys(items)) {
        q = {
            title: items[key],
            name: key,
            type: "rating",
            displayMode: "buttons",
            isRequired: required,
            rateValues: [
                {
                    value: 0,
                    text: "Not at all",
                },
                {
                    value: 0.5,
                    text: "Once or twice",
                },
                {
                    value: 1,
                    text: "Several days",
                },
                {
                    value: 2,
                    text: "More than half the days",
                },
                {
                    value: 3,
                    text: "Nearly every day",
                },
            ],
        }
        questions.push(q)
    }

    return { elements: questions }
}


const questionnaire_phq4 = {
    type: jsPsychSurvey,
    survey_json: function () {
        return {
            title: "About your mood",
            showQuestionNumbers: false,
            goNextPageAutomatic: true,
            pages: [
                {
                    elements: [
                        {
                            title: "All things considered, how satisfied are you with your life as a whole?",
                            name: "LifeSatisfaction",
                            type: "rating",
                            displayMode: "buttons",
                            rateCount: 11,
                            rateMin: 0,
                            rateMax: 10,
                            minRateDescription: "No satisfaction at all",
                            maxRateDescription: "Completely satisfied",
                            isRequired: true,
                        },
                    ],
                },
                make_phq4(items_phq4),
            ],
        }
    },
    data: {
        screen: "questionnaire_phq4",
    },
}




// MINT ====================================================================================================================
// Multimodal Interoceptive Inventory
// Sum all items belonging to the same dimension to calculate score

const mint_items = {
    MINT_ExAc_1:
    "I can always accurately feel when I am about to fart",
    MINT_ExAc_2:
    "I can always accurately feel when I am about to sneeze",
    MINT_ExAc_3:
    "I can always accurately feel when I am about to burp",
    MINT_ReIA_4:
    "I always feel in my body if I am relaxed",
    MINT_ReIA_5:
    "I always know when I am relaxed",
    MINT_ReIA_6:
    "My body is always in the same specific state when I am relaxed",
    MINT_SexS_7:
    "During sex or masturbation, I often feel very strong sensations coming from my genital areas",
    MINT_SexS_8:
    "My genital organs are very sensitive to pleasant stimulations",
    MINT_SexS_9:
    "When I am sexually aroused, I often notice specific sensations in my genital area (e.g., tingling, warmth, wetness, stiffness, pulsations)",
    MINT_CaCo_10:
    "Sometimes my breathing becomes erratic or shallow and I often don't know why",
    MINT_CaCo_11:
    "I often feel like I can't get enough oxygen by breathing normally",
    MINT_CaCo_12:
    "Sometimes my heart starts racing and I often don't know why",
    MINT_Urin_13:
    "I sometimes feel like I need to urinate or defecate but when I go to the bathroom I produce less than I expected",
    MINT_Urin_14:
    "I often feel the need to urinate even when my bladder is not full",
    MINT_Urin_15:
    "Sometimes I am not sure whether I need to go to the toilet or not (to urinate or defecate)",
    MINT_Derm_16:
    "In general, my skin is very sensitive",
    MINT_Derm_17:
    "My skin is susceptible to itchy fabrics and materials",
    MINT_Derm_18:
    "I can notice even very subtle stimulations to my skin (e.g., very light touches)",
    MINT_Sati_19:
    "I don't always feel the need to eat until I am really hungry",
    MINT_Sati_20:
    "Sometimes I don't realise I was hungry until I ate something ",
    MINT_Sati_21:
    "I don't always feel the need to drink until I am really thirsty",
    MINT_Olfa_22:
    "I often check the smell of my armpits",
    MINT_Olfa_23:
    "I often check the smell of my own breath",
    MINT_Olfa_24:
    "I often check the smell of my farts",
    MINT_Resp_25:
    "In general, I am very sensitive to changes in my breathing",
    MINT_Resp_26:
    "I can notice even very subtle changes in my breathing",
    MINT_Resp_27:
    "I am always very aware of how I am breathing, even when I am calm",
    MINT_Card_28:
    "In general, I am very sensitive to changes in my heart rate",
    MINT_Card_29:
    "I often notice changes in my heart rate",
    MINT_Card_30:
    "I can notice even very subtle changes in the way my heart beats",
    MINT_Gast_31:
    "I can notice even very subtle changes in what my stomach is doing",
    MINT_Gast_32:
    "In general, I am very sensitive to what my stomach is doing",
    MINT_Gast_33:
    "I am always very aware of what my stomach is doing, even when I am calm"
}


function make_mint(items, required = false, ticks = ["Disagree", "Agree"]) {
    items = shuffleObject(items)

    questions = []

    // Make questions
    for (const key of Object.keys(items)) {
        q = {
            title: items[key],
            name: key,
            type: "rating",
            displayMode: "buttons",
            // scaleColorMode: "colored",
            isRequired: required,
            minRateDescription: ticks[0],
            maxRateDescription: ticks[1],
            rateValues: [0, 1, 2, 3, 4, 5, 6],
        }
        questions.push(q)
    }

        // Define attention check
        const attentionCheck = {
            title: "I can always accurately answer to the extreme left on this question to show that I am reading it",
            name: "mint_attention_check",
            type: "rating",
            displayMode: "buttons",
            isRequired: required,
            minRateDescription: ticks[0],
            maxRateDescription: ticks[1],
            rateValues: [0, 1, 2, 3, 4, 5, 6],
        };

    // Add attention check at end
    questions.push(attentionCheck)

    return { elements: questions }
}


const questionnaire_mint = {
    type: jsPsychSurvey,
    survey_json: function () {
        return {
            title: "About you and your body",
            description:
                "Please answer the following questions based on how accurately each statement describes you in general.",
            showQuestionNumbers: false,
            goNextPageAutomatic: true,
            pages: make_mint(mint_items),
        }
    },
    data: {
        screen: "questionnaire_mint",
    },
}



//---------------------------------------------------------------------------------------------------------------
/* Attitudes towards AI *==========================*/
// Beliefs about Artificial Images Technology (BAIT)
// History:
// - BAIT-Original: Items specifically about CGI and artificial media originally in Makowski et al. (FakeFace study)
// - BAIT-14: Validated in FictionEro (with new items + removal of "I think"), where it was mixed with the 6 most
//   loading items of the positive and negative attitutes dimensions from the General Attitudes towards
//   Artificial Intelligence Scale (GAAIS; Schepman et al., 2020, 2022)
// - BAIT-14: Used in FakeNewsValidation
// - BAIT-12 (Current version): Used in FakeFace2.
//   - Removed 2 GAAIS items (GAAIS_Negative_9, GAAIS_Positive_7)
//   - Replaced "Artificial Intelligence" with "AI"
//   - Change display (Analog scale -> Likert scale)

const bait_items = [
    // BAIT-12 items used in FakeFace2 study
    "Current AI algorithms can generate very realistic images",
    "Images of faces or people generated by AI always contain errors and artifacts",
    "Videos generated by AI have obvious problems that make them easy to spot as fake",
    "Current AI algorithms can generate very realistic videos",
    "Computer-Generated Images (CGI) are capable of perfectly imitating reality",
    "Technology allows the creation of environments that seem just as real as reality",
    "AI assistants can write texts that are indistinguishable from those written by humans",
    "Documents and paragraphs written by AI usually read differently compared to Human productions",

    // Attitudes (adapted from GAAIS; Schepman et al., 2023)
    "AI is dangerous",
    "I am worried about future uses of AI",
    "AI is exciting",
    "Much of society will benefit from a future full of AI",

    // Art related items
    "Human-made art evokes stronger emotional responses than AI-generated art",
    "AI-generated art can sometimes surpass human creativity and artistic value"
    
    // Potential additional items that could be added that are more relevant to attitudes towards AI art, taken from the FictionEro study
    // Discrimination
    //"I can easily distinguish between real and AI-generated images",
    //"I am bad at telling if images are real or AI-generated",
    // BAIT_TextDifferentiation: "I often find it challenging to differentiate between AI-generated and human-written text",
    //"I can accurately detect subtle differences between AI from human-created content",

    // Bias
    /*"Human creators bring a unique perspective that AI cannot replicate",
    "AI-generated media can sometimes surpass human creativity in terms of innovation",
    "AI-generated content often feels impersonal compared to human-generated media",
    "AI-generated content tends to be more interesting and engaging than human-generated content",
    "Human-generated art evokes stronger emotional responses than AI-generated art",
    "I am more likely to appreciate content when I know it is created by humans rather than AI",
    "I am more likely to trust content when I know it is created by a human rather than AI",*/
]

const bait_dimensions = [
    "BAIT_1_ImagesRealistic",
    "BAIT_2_ImagesIssues",
    "BAIT_3_VideosIssues",
    "BAIT_4_VideosRealistic",
    "BAIT_5_ImitatingReality",
    "BAIT_6_EnvironmentReal",
    "BAIT_7_TextRealistic",
    "BAIT_8_TextIssues",
    "BAIT_9_Dangerous", // GAAIS_Negative_10
    "BAIT_10_Worry", // GAAIS_Negative_15
    "BAIT_11_Exciting", // GAAIS_Positive_12
    "BAIT_12_Benefit", // GAAIS_Positive_17

    "BAIT_13_ArtIssues",
    "BAIT_14_ArtRealistic",

    /*"BAIT_13_ImageDistinctionEasy",
    "BAIT_14_ImageDistinctionBad",
    "BAIT_15_ContentDetection",
    "BAIT_16_UniqueHuman",
    "BAIT_17_InnovativeAI",
    "BAIT_18_ImpersonalAI",
    "BAIT_19_InterestingAI",
    "BAIT_20_EmotionalHuman",
    "BAIT_21_PreferenceHuman",
    "BAIT_22_TrustHuman",  */  
]

function bait_questions(
    required = false,
    ticks = ["Disagree", "Agree"], // In Schepman et al. (2022) they removed 'Strongly'
    items = bait_items,
    dimensions = bait_dimensions
) {
    // AI Expertise
    var aiexpertise = [
        {
            title: "How knowledgeable do you consider yourself about Artificial Intelligence (AI) technology?",
            name: "BAIT_AI_Knowledge",
            type: "rating",
            displayMode: "buttons",
            isRequired: required,
            minRateDescription: "Not at all",
            maxRateDescription: "Expert",
            rateValues: [0, 1, 2, 3, 4, 5, 6],
        },
    ]

    // Make questions
    var questions = []
    for (const [index, element] of items.entries()) {
        q = {
            title: element,
            name: dimensions[index],
            type: "rating",
            displayMode: "buttons",
            // scaleColorMode: "colored",
            isRequired: required,
            minRateDescription: ticks[0],
            maxRateDescription: ticks[1],
            rateValues: [0, 1, 2, 3, 4, 5, 6],
        }
        questions.push(q)
    }

    // Randomize order
    for (let i = questions.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1))
        ;[questions[i], questions[j]] = [questions[j], questions[i]]
    }

    return [
        { elements: aiexpertise },
        {
            elements: questions,
            description:
                "We are interested in your thoughts about Artificial Intelligence (AI). Please read the statements below carefully and indicate the extent to which you agree with each statement.",
        },
    ]
}


// Feedback ========================================================================================================
function bait_feedback(screen = "questionnaire_bait") {
    let dat = jsPsych.data.get().filter({ screen: screen })
    dat = dat["trials"][0]["response"]

    let score = (dat["BAIT_11_Exciting"] + dat["BAIT_12_Benefit"]) / 2
    let score_pop = 3.89 // Computed in FictionEro
    let text = "XX"
    if (score < score_pop) {
        text = "less"
    } else {
        text = "more"
    }

    // Round to 1 decimal (* 10 / 10)
    score = Math.round((score / 6) * 100 * 10) / 10
    score_pop = Math.round((score_pop / 6) * 100 * 10) / 10

    let feedback =
        "<h2>Results</h2>" +
        "<p>Based on your answers, it seems like you are <b>" +
        text +
        "</b> enthusiastic about AI (your score: " +
        score +
        "%) compared to the average population (average score: " +
        score_pop +
        "% positivity).<br></p>"
    return feedback
}

// Initialize experiment =================================================
var questionnaire_bait = {
    type: jsPsychSurvey,
    survey_json: {
        title: "Artificial Intelligence",
        showQuestionNumbers: false,
        goNextPageAutomatic: true,
        pages: bait_questions(),
    },
    data: {
        screen: "questionnaire_bait",
    },
}

var feedback_bait = {
    type: jsPsychHtmlButtonResponse,
    stimulus: function () {
        return bait_feedback((screen = "questionnaire_bait"))
    },
    choices: ["Continue"],
    data: { screen: "feedback_bait" },
}


// ERNS ===================================================================================================================
// Emotional Reactivity and Numbing Scale (Orsillo et al., 2007)
// General subscale - Measure of general emotional numbness/hyperactivity
// High score, greater emotional reactivity
// Low score, indicates emotional numbing

const ERNS_items = {
    ERNS_1:
    "I am able to feel a wide range of emotions (e.g., happiness, sadness, anger, and fear)",
    ERNS_2_r:
    "I feel cut off from my emotions", // r
    ERNS_3_r:
    "In situations when other people have strong emotional responses, I don't feel anything at all", // r
    ERNS_4_r:
    "There are certain emotions that I cannot feel", // r
    ERNS_5:
    "I think of myself as a very emotional person",
    ERNS_6_r:
    "I feel like I am emotionally numb", // r
    ERNS_7_r:
    "I have a hard time feeling close to people, even my friends or family", // r
    ERNS_8_r:
    "There are some negative emotions that I rarely feel even when there is reason to feel them" // r
}


function make_ERNS(items, required = false, ticks = ["Disagree", "Agree"]) {
    items = shuffleObject(items)

    questions = []

    // Make questions
    for (const key of Object.keys(items)) {
        q = {
            title: items[key],
            name: key,
            type: "radiogroup",
            colCount: 5,
            isRequired: required,
            choices: [
                "Not at all typical of me",
                "A little typical of me",
                "Somewhat typical of me",
                "Very typical of me",
                "Entirely typical of me"
            ]
        }
        questions.push(q)
    }
    return [
        {
            elements: questions,
            description:
                "Rate how much each of the statements describes your tendency to experience these feelings. Please note, we are NOT asking about how likely you would be to show these feelings to other people. Instead, we are asking how you would feel inside. Please keep this in mind as you read each item.",
        },
    ]
}


const questionnaire_ERNS = {
    type: jsPsychSurvey,
    survey_json: function () {
        return {
            title: "Emotional Sensitivity",
            showQuestionNumbers: false,
            goNextPageAutomatic: true,
            pages: make_ERNS(ERNS_items),
        }
    },
    data: {
        screen: "questionnaire_ERNS",
    },
}


// VVIQ ==================================================================================================================
// Vividness of Visual Imagery Questionnaire (Marks, 1973)
// Measures the vividness of someones voluntary visual imagery

const vviq_items = [
    "The exact contours of face, head, shoulders and body",
    "Characteristic poses of head, attitudes of body etc",
    "The precise carriage, length of step etc., in walking.",
    "The different colors worn in some familiar clothes.",

    "The sun rising above the horizon into a hazy sky",
    "The sky clears and surrounds the sun with blueness",
    "Clouds. A storm blows up with flashes of lightning",
    "A rainbow appears",

    "The overall appearance of the shop from the opposite side of the road",
    "A window display including colours, shapes and details of individual items for sale",
    "You are near the entrance. The colour, shape and details of the door",
    "You enter the shop and go to the counter. The counter Assistant serves you. Money changes hands.",

    "The contours of the landscape",
    "The colour and shape of the lake",
    "The colour and shape of the trees.",
    "A strong wind blows on the trees and on the lake causing reflections in the water"
]

const vviq_dimensions = [
    "relative_or_friend_1",
    "relative_or_friend_2",
    "relative_or_friend_3",
    "relative_or_friend_4",

    "rising_sun_5",
    "rising_sun_6",
    "rising_sun_7",
    "rising_sun_8",

    "familiar_shop_9",
    "familiar_shop_10",
    "familiar_shop_11",
    "familiar_shop_12",
    
    "country_scene_13",
    "country_scene_14",
    "country_scene_15",
    "country_scene_16"
]

function vviq_questions(
    required = false,
    items = vviq_items,
    dimensions = vviq_dimensions
){
    var questions1_4 = []
    var questions5_8 = []
    var questions9_12 = []
    var questions13_16 = []

    for(const [index, element] of items.entries()){
        q = {
            title: element,
            name: dimensions[index],
            type: "radiogroup",
            isRequired: required,
            choices: [
                "No image at all, you only 'know' that you are thinking of the object",
                "Dim and vague image",
                "Moderately realistic and vivid",
                "Realistic and reasonably vivid",
                "Perfectly realistic, as vivid as real seeing"
            ]
        }

        if (index < 4){
            questions1_4.push(q)
        } else if (index < 8){
            questions5_8.push(q)
        } else if (index < 12){
            questions9_12.push(q)
        } else {
            questions13_16.push(q)
        }
    }
    return [
  {
    title: "Think of some relative or friend whom you frequently see (but who is not with you at present) and consider carefully the picture that comes before your mind's eye.",
    elements: questions1_4
  },
  {
    title: "Visualise a rising sun. Consider carefully the picture that comes before your mind's eye.",
    elements: questions5_8
  },
  {
    title: "Think of the front of a shop which you often go to. Consider the picture that comes before your mind's eye.",
    elements: questions9_12
  },
  {
    title: "Finally think of a country scene which involves trees, mountains and a lake. Consider the picture that comes before your mind's eye.",
    elements: questions13_16
  }
    ]
}

var questionnaire_vviq = {
    type: jsPsychSurvey,
    survey_json: {
        title: "Visualisation Task",
        //description:
        //    "For each scenario try to form a mental picture of the people, objects, or setting. If you do not have a visual image, rate vividness as '1'. Only use '5' for images that are as lively and vivid as real seeing.",
        showQuestionNumbers: false,
        goNextPageAutomatic: true,
        pageNextText: "Next",
        pagePrevText: "Previous",
        showProgressBar: "aboveHeader",
        pages: [
            {
                elements: [
                    {
                    type: "html",
                    html: 
                    `<div style="font-size: 1.1em; margin-bottom: 10px;">
                        For this task you will be presented with <strong>four scenarios</strong>. For each one, try to <strong>form a mental picture</strong> of the people, objects, or setting. 
                        If you do not have a visual image, rate vividness as <strong>'1'</strong>. Only use <strong>'5'</strong>, for images that are as lively and vivid as real seeing.
                    </div>`
                    }
                ]
            },
            ...vviq_questions(),
        ]
    },
    data: {
        screen: "questionnaire_vviq",
    },
}

//---------------------------------------------------------------------------------------------------------------------
// Art expertise
var art_expertise = {
    type: jsPsychSurvey,
    survey_json: {
        title: "Art Expertise",
        //description: "Please rate how knowledgeable you percieve yourself to be about art, such as how familiar you are with styles, artists or movements.",
        showQuestionNumbers: false,
        pages: [
            {
                elements: [
                    {
                        type: "html",
                        html: `Please rate how knowledgeable you percieve yourself to be about art, such as how familiar you are with styles, artists or movements.`
                    },
                    {
                        name: art_expertise,
                        title: "I consider myself to be knowledgeable in art",
                        type: "rating",
                        isRequired: true,
                        minRateDescription: "Not at all",
                        maxRateDescription: "Very much so",
                        rateValues: [0, 1, 2, 3, 4, 5, 6],
                    }
                ]
            }
        ]
    }
}

// Randomize order of questionnaires=========================================================================================
// Group bait questionnaire with bait feedback
const bait_grouped = [
  questionnaire_bait,
  feedback_bait
]

let questionnaires = [
  questionnaire_mint,
  questionnaire_vviq,
  questionnaire_phq4,
  questionnaire_ERNS,
  bait_grouped
]

// Shuffle order of questionnaires 
questionnaires = shuffleArray(questionnaires);

// Flatten nested array  
questionnaires = questionnaires.flat()


