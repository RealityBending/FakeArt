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

<p>In the <b>second stage</b>, you were told that the <u>labels had been mixed up</u>, and you were then asked to express <b>your own beliefs</b> about whether the artwork was <b style="color: #880E4F">AI-Generated or Human-Made</b> and if it was an <b style="color: rgb(32, 14, 136)">Original or a Copy</b> (i.e., an original Human creation or AI-Generated with prompts "<i>to be original</i>" and "<i>make something new</i>" - or a Human Forgery, or AI-Generated with the prompt to mimic a certain style, artist, or artwork).</p>
<p>In other words, you had to choose between 4 categories: "<b>Human Original</b>", "<b>Human Forgery</b>", "<b>AI Original</b>", "<b>AI Copy</b>"</p>

<div style="margin-top: 8px; text-align: center;">
    <img src="media/exp1_graphic2.gif" style="max-width: 720px; width: 100%; height: auto; display: inline-block; border-radius: 4px;">
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
<div style="display: flex; align-items: flex-start; gap: 24px;">
    <!-- Left column: text -->
    <div style="flex: 1; min-width: 0; text-align: left;">
        <h3>The current study</h3>
        <p>In this follow-up study, we will show you the artworks from the previous study, <u>mixed with some new artworks.</u></p>

        <h4>1) Beauty and Self-Relevance</h4>
        <p>Firstly, we would like you to rate the <b>beauty</b> of each artwork. How artistically beautiful is the image? This question is about the <i>aesthetic quality</i> of the artwork in terms of composition, colours, and execution.</p>
        <p>Secondly, we would like you to indicate, for each artwork, how <b>personally relevant</b> it is to you. In other words, how much the artwork relates to your past experiences, personality, hobbies, events in your life, etc. (e.g., "the artwork depicts a cat and I am a cat lover", "my uncle paints abstract art and this painting reminds me of him"), <b>regardless of whether you think it is beautiful or not</b>. You may find an ugly artwork personally relevant, or a pleasing artwork to not be relevant to you. Similarly, a familiar painting may not feel self-relevant to you and vice versa.</p>

        <h4>2) Recognition</h4>
        <p>Afterwards, for each artwork, we would like you to indicate whether you <b>recognise</b> it from the previous study. You should answer "Yes" if you recall seeing this artwork in the previous experiment or "No" if you think this is a new artwork not shown in the previous experiment.</p>
        <p>If you do <b>not</b> recognise an artwork as being shown in the previous experiment, we would then like you to rate the extent to which you could easily believe the artwork was created by AI: the AI-likeness of the artwork.</p>

        <h4>3) Memory</h4>
        <p><i>If</i> you recognise an artwork from the previous study, you will be asked the following questions relating to details of your <b>memory</b>:</p>
        <ul>
            <li><b>Label</b>: Which category (<b style="color: #ff0000">Original</b>/<b style="color: #0000ff">AI-Generated</b>/<b style="color: #00820e">Human Forgery</b>) was the artwork said to have belonged to in the first stage of the previous study?</li>
            <li><b>Your own beliefs</b>: What did you answer the real nature of the artwork was in the second stage of the previous study? (i.e., did you think it was Human Original, Human Forgery, AI Original, or AI Copy). Remember that we are not asking about what you think now, but how well you are able to remember your own answers.</li>
        </ul>
        <p><b>We know that remembering all of this is very difficult, as the experiment was a long time ago!</b> It is <b>totally normal</b> to not remember much of it. But we are still very interested in your best guess, even if you don't think you can remember!</b></p>

    </div>

    <!-- Right column: image -->
    <div style="flex: 1 1 30%; max-width: 60%; text-align: center;">
        <img src="media/instructions_update_2.jpg" style="width: 110%; height: auto; display: block; border-radius: 4px;" alt="Instructions illustration">
    </div>
</div>
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
<p style="text-align:center">Thank you for your participation. <b style="color: red;">The Prolific completion code is <a href="https://app.prolific.com/submissions/complete?cc=C1IX56QL">C1IX56QL</a> (you will be redirected to the completion page after this experiment)</b>. You may now close the tab.</p>
                            `,
                    },
                ],
            },
        ],
    },
}
