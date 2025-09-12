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
                        html: `<div style="text-align: center;"></div>`,
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
<p><b>Welcome to our study!</b> It is a follow-up of the previous study you completed a few weeks ago on AI and art. Let us remind you of some of the details.</p>

<h3>What you did last time</h3>

<div style="display: flex; align-items: flex-start; gap: 24px;">
    <div style="flex: 1; min-width: 0; text-align: left;">
        <p>In the <b>first stage</b> of the previous study, you were shown <b>labels</b> before each artwork, and were asked to rate those artworks on different rating scales.</p>
        <p>There were 3 different labels:</p>
        <ul>
            <li><b style="color: #ff0000">Original</b></li>
            <li><b style="color: #0000ff">AI-Generated</b></li>
            <li><b style="color: #00820e">Human Forgery</b></li>
        </ul>
    </div>
    <div style="flex: 0 0 50%; max-width: 50%;">
        <img src="media/exp1_graphic1.jpg" style="width: 100%; height: auto; display: block; border-radius: 4px;">
        <p style="text-align: center;"><i>First stage</i></p>
    </div>
</div>

<p>In the <b>second stage</b>, you were told that the <u>labels had been mixed up</u>, and you were then asked to express <b>your own beliefs</b> about whether the artwork was <b style="color: #880E4F">AI-generated or Human-made</b> and if it was an <b style="color: rgb(32, 14, 136)">Original or a Copy</b> (i.e., an original Human creation or AI-Generated with prompts "<i>to be original</i>" and "<i>make something new</i>"—or a Human Forgery, or AI-Generated with the prompt to mimic a certain style, artist, or artwork).</p>
<p>In other words, you had to choose between 4 categories: "<b>Human Original</b>", "<b>Human Forgery</b>", "<b>AI Original</b>", "<b>AI Copy</b>"</p>

<div style="margin-top: 8px; text-align: center;">
    <img src="media/exp1_graphic2.jpg" style="max-width: 720px; width: 100%; height: auto; display: inline-block; border-radius: 4px;">
    <p><i>Second stage</i></p>
  
</div>

<p><b>At the end of the experiment</b>, it was revealed that <b>all the artworks had actually been Human originals</b>.</p>

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

<h3>The current memory study</h3>
        <p>In this follow-up study, we will show you the artworks from the previous study, <u>mixed with some new artworks.</u></p>

        <h4>1) Personal Relevance</h4>
        <p>Firstly, we would like you to indicate, for each artwork, how <b>personally relevant</b> it is to you. In other words, how much the artwork relates to your past experiences, interests, personality, events in your life, etc.  (e.g., "the artwork depicts a cat and I am a cat lover", "my uncle paints abstract art and this painting reminds me of him"), <b>regardless of whether you think it is beautiful or not</b>.</p> You may find an ugly artwork personally relevant, or a pleasing artwork to not be relevant to you. Similarly, a familiar painting may not feel self-relevant to you and vice versa.

        <h4>2) Recognition</h4>

        <h4>3) Memory</h4>
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

        <p>Remember that we are not asking about what you think now, but how well you are able to remember your own answers. <b>If you don't remember your answer, just make your best guess!</b></p>
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
