var participant_id = {
    type: jsPsychSurvey,
    survey_json: {
        title: "Before we begin",
        completeText: "Continue",
        pageNextText: "Next",
        pagePrevText: "Previous",
        goNextPageAutomatic: false,
        showQuestionNumbers: false,
        pages: [
            {
                elements: [
                    {
                        type: "html",
                        html: `<div style="text-align: center</div>`,
                    },
                    {
                        type: "text",
                        title: "Please enter the same 6-character participant ID as used in the previous study, to ensure that results can be matched between both studies. [TYPE OUT ID CODE RULES BELOW]",
                        name: "ID",
                        isRequired: true,
                        inputType: "text",
                        placeholder: "e.g., xxxxxx",
                    },
                ],
            },
        ],
    },
}

const memory_instructions = {
    type: jsPsychSurvey,
    data: { screen: "memory_instructions" },
    on_finish: function () {
        memory_trialnumber = 1
    },
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
<div style="flex: 2; text-align: left;">
        <p>Thank you for participating in our study. This study constitutes a follow-up of the previous study you completed in investigating how new technology impacts human appreciation of art.</p>

<h3>What you saw last time</h3>
        <p>In the <b>first stage</b> of the previous study, you were presented with labels assigned to various artworks, and were asked to rate those artworks on different rating scales.
        Afterwards, you were told that some images had been intentionally mislabelled (the idea that an artwork was labelled as AI-generated when it was actually a human original, or a forgery, or vice versa).</p> 
        <p>As a reminder, artworks were labelled according to the following categories:</p>
        <ul>
            <li><b style="color: #ff0000">Original:</b> Images of original paintings (by humans) taken from public artwork databases.</li>
            <li><b style="color: #0000ff">AI-Generated:</b> Realistic painting images generated using platforms like <i>Midjourney</i> and <i>Stable Diffusion</i>, either in a new style or inspired by existing artists or artworks.</li>
            <li><b style="color: #00820e">Human Forgery:</b> Human copies of famous paintings or works mimicking a style, often by anonymous forgers, intended to be sold as originals.</li>
        </ul>

    <p><b>Below is a representation of what you saw in the initial section of the previous study.</b></p>
    <div style = "text-align: center;">
        <img src = "media/exp1_graphic1.jpg" style = "width: 90%"; "height: 90%">
    </div>                   


    <p>In the <b>second stage</b>, after being told that the labels had been mixed up, you were then asked to categorise each artwork according to two different questions:</p>
    <ul>
            <li><b style="color: #880E4F">AI-generated or Human-created?</b> Do you think the image corresponds to a real painting (painted by a Human) or is AI-Generated?</li>
            <li><b style="color: rgb(32, 14, 136)">Original or Copy?</b> Do you think the artwork is an "Original" (an original Human creation, or AI-Generated with prompts "<i>to be original</i>" and <i>"make something new</i>") or a Copy (a Human Forgery, or AI-Generated with the prompt to mimic a certain style, artist, or artwork)?</li>
        </ul>

    <p><b>Below is a representation of what you saw in the second section of the previous study.</b></p>
    <div style = "text-align: center;">
        <img src = "media/exp1_graphic2.jpg" style = "width: 85%"; "height: 85%">
    </div>

    <p>At the end of the study, you were told that all artworks presented were actually <b>human originals</b>.

    <p>For the remainder of the study, it is <b>very important</b> that you understand the distinction between the above labels and categories.</p>

`,
                    },
                ],
            },
            {
                elements: [
                    {
                        type: "html",
                        name: "Instructions",
                        html: `
<h1>Instructions</h1>
<div style="flex: 2; text-align: left;">

<h3>What you need to do in this study</h3>
        <p>In this follow-up study, we will briefly present a number of artworks. Some are from the previous study, whereas others will be new.
        
        
        <p>If you recognise an artwork from the previous study, you will be asked the following questions relating to your <b>memory</b>:</p>
        <ul>
            <li><b style="color: #FFA500">Artwork category:</b> Which category (<b style = "color: #ff0000">Original</b>/<b style = "color: #0000ff">AI-Generated</b>/<b style = "color: #00820e">Human Forgery</b>) was the artwork said to have belonged to in the first stage of the previous study?
            <div style = "text-align: center;">
            <li><b style="color: #880E4F">AI-Generated or Human-Created?</b> In the second stage of the previous study, did you think that the artwork corresponded to a <b>real painting</b> (painted by a human, either an <b>Original</b> or <b>Human Forgery</b>) or that it was <b>AI-Generated</b>?</li>
            <li><b style="color: rgb(32, 14, 136)">Original or Copy?</b> In the second stage of the previous study, did you think the artwork was an <b>"Original"</b> (an original Human creation, or AI-generated with prompts <i>"to be original"</i> and <i>"make something new"</i>) or a <b>Copy/Forgery</b> (a Human forgery, or AI-generated with the prompt to mimic a certain style, artist or artwork)?</li>
        </ul>
        <div style = "text-align: center;">
            <img src = "media/instructions.jpg"></div>
        </div>
            
        <p>For the remainder of the study, it is <b>very important</b> that you understand the distinction between the above labels and categories.</p>                

        <p><b>Press "Let's start" when you are ready to begin the experiment.</b></p>
`,
                    },
                ],
            },
        ],
    },
}

var endscreen = {
    type: jsPsychSurvey,
    survey_json: {
        showQuestionNumbers: false,
        completeText: "Continue",
        pages: [
            {
                elements: [
                    {
                        type: "html",
                        name: "Debrief",
                        html: `
<h2 style='color:green;';"text-align: center;">Data saved successfully!</h2>
<p style="text-align:center">Thank you for your participation. You may now close the tab.</p>
                            `,
                    },
                ],
            },
        ],
    },
}
