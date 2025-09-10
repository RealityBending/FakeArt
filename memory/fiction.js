var fiction_preloadstims_exp2 = {
    type: jsPsychPreload,
    images: [
      ...stimuli_list.map((a) => "./../experiment/stimuli/stimuli/" + a.Item),
    ],
    message: "Please wait while the experiment is being loaded (it can take a few minutes)",
}

// Condition assignment ==========================================================
function shuffleArray(array) {
    for (let i = array.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1))
        ;[array[i], array[j]] = [array[j], array[i]]
    }
    return array
}

var color_cues = shuffleArray(["red", "blue", "green"])
color_cues = {
    AI: color_cues[0],
    Human: color_cues[1],
    Forgery: color_cues[2],
}

// Screens =======================================================================
const fiction_instructions1_exp2 = {
    type: jsPsychSurvey,
    data: { screen: "fiction_instructions1_exp2" },
    survey_json: {
        showQuestionNumbers: false,
        completeText: "Let's start",
        pages: [
            {
                elements: [
                    {
                        type: "html",
                        name: "Instructions",
                        html: `
  <h1>Instructions</h1>
  <h3>Part 1/2</h3>
  <h3>What you did last time</h3>
  <h4>Phase 1</h4>
  <div style="text-align: left;">
    <p>In Phase 1 of the previous study you were presented with a label (Original/AI/forgery), an artwork, and you then completed the rating scales below.</p>

    <div style="display: flex; align-items: center; margin-bottom: 20px; margin-top:30px;">
      <div style="flex: 2;">
        <div style="border: 1px dashed gray;padding-right:15px;">
          <ul style='list-style-type:none;'>
            <p>
              <li>
                <b style="color: ${color_cues["Human"]}">Original</b><br>
                Human-Created Original Artworks
              </li>
            </p>
            <p>
              <li>
                <b style="color: ${color_cues["AI"]}">AI-Generated</b><br>
                AI-Generated Artworks
              </li>
            </p>
            <p>
              <li>
                <b style="color: ${color_cues["Forgery"]}">Human Forgery</b><br>
                Copies/Forgeries of Human-Created Artworks
              </li>
            </p>
          </ul>
        </div>
        <p style ='color: gray;'>Labels Shown Before Artworks</p>
      </div>

      <div style="flex: 1; text-align: center;">
        <img src="./media/arrow.png" alt="Arrow" style="width:100%; max-height: 100px; max-width: 70px;">
      </div>

      <div style="flex: 1; text-align: center;">
        <img src="./../experiment/media/example_original.png" alt="Artwork" style="width:100%; max-height: 120px; max-width: 200px;">
        <p style ='color: gray'>Artwork</p>
      </div>

      <div style="flex: 1; text-align: center;">
        <img src="./media/arrow.png" alt="Arrow" style="width:100%; max-height: 100px; max-width: 70px;">
      </div>

      <div style="flex: 1; text-align: center;">
        <img src="./media/ratingscales.jpg" alt="Rating Scales" style="width:200%;max-height: 400px; max-width: 300px;">
        <p style = 'color: gray;'>Rating Scales</p>
      </div>

    </div>
    <h4>Phase 2</h4>
    <div style="text-align: left;">
      <p>In Phase 2, we stated the labels of the images had been mixed up, and you then rated your beliefs on which images belonged to what label.</p>
      
      <div style="display: flex; align-items: center; margin-bottom: 20px; margin-top:30px;">
        <div style="flex: 1; text-align: center;">
          <img src="./../experiment/media/example_original.png" alt="Artwork" style="width:100%; max-height: 120px; max-height: 400px; max-width: 300px;">
          <p style ='color: gray'>Artwork</p>
        </div>

        <div style="flex: 1; text-align: center;">
          <img src="./media/arrow.png" alt="Arrow" style="width:100%; max-height: 100px; max-width: 70px;">
        </div>

        <div style="flex: 1; text-align: center;">
          <img src="./media/labelscales.jpg" alt="Label Rating Scales" style="width:200%; max-height: 500px; max-width: 400px;">
          <p style = 'color: gray;'>Label Scales</p>
        </div>

      </div>
    </div>
`,
},
                ],
            },
            {
                elements: [
                    {
                        type: "html",
                        name: "Instructions2",
                        html: `
    <h3>Part 2/2</h3>
    <h1>Instructions</h1>
    <h3>What you need to do</h3>
    <p>Each artwork will be briefly re-presented on the screen along with new artworks. After each artwork, you will be asked the following:</p>
    <ul>
      <li>
        <b>Assigned Label -</b> 
        In the previous study, which label was the artwork assigned:
          (<b style="color: ${color_cues["Human"]}">Original</b>/
          <b style="color: ${color_cues["AI"]}">AI-Generated</b>/
          <b style="color: ${color_cues["Forgery"]}">Human Forgery</b>)?
      <img src="./media/guesslabels.jpg" alt="Displayed Label Options" style="width:100%; max-width: 500px;">
      </li>
      <br>
      <li>
          <b>Guessed Label -</b> In the previous study, which label did you think the artwork belonged to:
           <br>(Original Human Creation/ Original AI-Generation/ AI-Generated Forgery/ Human Forgery)? 
           <br>
          <img src="./media/guesslabels.jpg" alt="Guessed Label Options" style="width:100%; max-width: 500px;">
      </li>
    </ul>     
`,
                    },
                ],
            },
        ],
    },
}

// Fixation Cross ================================================================
var fiction_fixation_exp2_1 = {
    type: jsPsychHtmlKeyboardResponse,
    stimulus: "<div style='font-size:500%; position:fixed; text-align: center; top:50%; bottom:50%; right:20%; left:20%'>+</div>",
    choices: ["s"],
    trial_duration: 500,
    save_trial_parameters: { trial_duration: true },
    data: {
        screen: "fiction_fixation_exp2_1a",
    },
}

// Display Stimuli Images ========================================================
var fiction_exp2_showimage1 = {
    type: jsPsychImageKeyboardResponse,
    stimulus: function () {
      return "./../experiment/stimuli/stimuli/" + jsPsych.evaluateTimelineVariable("Item")
    },
    stimulus_width: function () {
        let ratio = jsPsych.evaluateTimelineVariable("Width") / jsPsych.evaluateTimelineVariable("Height")
        return Math.round(Math.min(0.9 * window.innerHeight * ratio, 0.9 * window.innerWidth))
    },

    stimulus_height: function () {
        let ratio = jsPsych.evaluateTimelineVariable("Width") / jsPsych.evaluateTimelineVariable("Height")
        return Math.round(Math.min((0.9 * window.innerWidth) / ratio, 0.9 * window.innerHeight))
    },
    trial_duration: 2500,
    choices: ["s"],
    save_trial_parameters: { trial_duration: true },
    data: function () {
        return {
            screen: "fiction_exp2_image1",
            item: jsPsych.evaluateTimelineVariable("Item"),
            window_width: window.innerWidth,
            window_height: window.innerHeight,
            trial_number: fiction_trialnumber,
        }
    },
    on_finish: function () {
        fiction_trialnumber += 1
    },
    extensions: [
        {
            type: jsPsychExtensionWebgazer,
            params: { targets: ["#jspsych-image-keyboard-response-stimulus"] },
        },
    ],
}

// Image Ratings and Categorisation ==============================================
var fiction_ratings1_exp2 = {
    type: jsPsychSurvey,
    survey_json: {
        goNextPageAutomatic: true,
        showQuestionNumbers: false,
        showNavigationButtons: false,
        title: function () {
            return "Rating - " + Math.round(((fiction_trialnumber - 1) / stimuli.length) * 100) + "%"
        },
        description: "Do you recognise the artwork?",
        pages: [
            {
                elements: [
                    {
                      type: "radiogroup",
                      name: "Recognition",
                      title: "I recognise this artwork from the previous study",
                      isRequired: true,
                      choices: ["Yes", "No"],
                    },
                    {
                      type: "rating",
                      name: "DisplayLabel",
                      title: "In the previous study, this artwork was labelled as...",
                      isRequired: true,
                      visibleIf: "{Recognition} = 'Yes'",
                      css_classes: ["colored-scale"],
                      displayMode: "buttons",
                      rateValues: [
                            { value: 0, text: "Original" },
                            { value: 1, text: "AI-Generated" },
                            { value: 2, text: "Human Forgery" },
                      ],
                    },
                    {
                      type: "rating",
                      name: "GuessLabel",
                      title: "In the previous study, I thought the artwork was...",
                      isRequired: true,
                      visibleIf: "{Recognition} = 'Yes'",
                      css_classes: ["colored-scale"],
                      displayMode: "buttons",
                      rateValues: [
                            { value: 0, text: "Original Human Creation" },
                            { value: 1, text: "Original AI-Generation" },
                            { value: 2, text: "AI-Generated Forgery" },
                            { value: 3, text: "Human Forgery" },
                            
                      ],
                    },
                ],
            },
        ],
    },
    data: {
        screen: "fiction_exp2_ratings1",
    },
}

// Break Addition Timeline =======================================================
function fiction_phase_exp2() { //start, end
  return {
    //timeline_variables: stimuli.slice(start, end),
    timeline_variables: shuffleArray(stimuli),
    timeline: [fiction_fixation_exp2_1, fiction_exp2_showimage1, fiction_ratings1_exp2],
  };
} 
//var midpoint = Math.ceil(stimuli.length / 2); // Avoid duplicity of stimuli during phase 1a and 1b